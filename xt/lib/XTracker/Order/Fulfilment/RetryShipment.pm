package XTracker::Order::Fulfilment::RetryShipment;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use URI;
use URI::QueryParam;

use XTracker::Error;
use XTracker::Config::Local qw( maybe_condition_config_var );
use XTracker::Database::Shipment qw( set_shipment_on_hold );
use XTracker::Database::Container qw( :utils );
use XTracker::Database::Stock qw( get_saleable_item_quantity );
use XTracker::Utilities qw( strip );
use XTracker::Constants::FromDB qw( :shipment_item_status :shipment_status :shipment_hold_reason  );

use XTracker::Handler::Situation;

my $redirect_default = '/Fulfilment/PackingException';

my $situations = {
    'retryShipment' => {
        fancy_name       => 'Retry Shipment',
        check_we_have    => [ qw( shipment_id ) ],
        redirect_on_fail => '/Fulfilment/Packing/CheckShipmentException',
    },
};

my $parameters = {
    shipment_id => {
        fancy_name => 'shipment',
        model_name => 'Public::Shipment',
    },
};

my $validators = {
    shipment_id => sub {
        my ($shipment,$checked_objects) = @_;

        die "Shipment still contains items to be dealt with at Packing Exception\n"
            unless $shipment->is_packing_exception_completed;
    }
};

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my ($situation,$bounce);

    eval {
        $situation = XTracker::Handler::Situation->new({
            situations               => $situations,
            parameters               => $parameters,
            validators               => $validators,
            redirect_on_fail_default => $redirect_default,
            handler                  => $handler,
        });
        $bounce=$situation->evaluate;
    };
    if ($@) {
        xt_warn($@);
        return $handler->redirect_to($redirect_default);
    }

    return $handler->redirect_to($bounce) if $bounce;

    my $shipment = $situation->get_checked_objects('shipment_id');
    my $channel = $shipment->get_channel;
    my $channel_name = $channel->name;
    my $dbh = $handler->{dbh};

    my $unselected_items = (
        $handler->iws_rollout_phase
            ? $shipment->selected_items
            : $shipment->unselected_items,
    );
    my @items_out_of_stock = ();
    while (my $shipment_item = $unselected_items->next) {
        # check stock
        my $variant_id = $shipment_item->get_true_variant->id;
        my $free_stock = $shipment_item->get_true_variant->product->get_saleable_item_quantity;

        if ( $free_stock->{ $channel_name }{ $variant_id } < 0 ) {
            # check for free stock LESS THAN 0 (not <=) because we have (deliberately) already
            # allocated stock without checking if free stock was available
            push @items_out_of_stock,$shipment_item;
        }
    }

    # get the totals we need to be able to construct accurate status messages:
    #
    #  + picked         == items in totes, which will be sent to the commissioner
    #  + to be replaced == total of all in- and out-of-stock replacement items
    #  + out of stock   == replacement items that are out of stock
    #  + in stock       == replacement items that are in stock
    my %item_counts = (
        picked         => $shipment->picked_items->count,
        to_be_replaced => $unselected_items->count,
        out_of_stock   => scalar (@items_out_of_stock),
    );
    $item_counts{in_stock} = $item_counts{to_be_replaced} - $item_counts{out_of_stock};

    my $err_message = "";
    my $message = "";
    if ($item_counts{out_of_stock}) {
        set_shipment_on_hold(
            $handler->{schema},
            $shipment->id,
            {
                status_id   => $SHIPMENT_STATUS__HOLD,
                operator_id => $handler->operator_id,
                reason      => $SHIPMENT_HOLD_REASON__STOCK_DISCREPANCY,
                norelease   => 1,
            },
        ) unless $shipment->is_on_hold;

        $err_message = replacement_on_hold_message(
            \%item_counts,
            \@items_out_of_stock,
            $shipment->id,
        );
    } else {
        # web stock already decremented, just display message
        if ($item_counts{picked}) {
            $message = to_packing_message(\%item_counts, $shipment->id);
        }
        else {
            $message = replacement_message(\%item_counts, $shipment->id);
        }
    }

    $shipment->discard_changes;
    # will pause if shipment on hold, otherwise unpause
    $handler->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentWMSPause', $shipment );

    # IWS-specific "let's try this shipment again"
    $shipment->send_to_commissioner;
    # PRL-specific "get me some more items"
    $shipment->allocate({ operator_id => $handler->{data}{operator_id} });

    if ($shipment->is_pigeonhole_only) {
        $message .= ". " if ($message);
        $message .= "Please return pigeon hole items to their original pigeon holes and ";
        if ($shipment->is_on_hold) {
            $message .= "put any labels and paperwork to one side until the shipment comes off hold. When the shipment has been resolved, take the labels and paperwork to a packer.";
        } elsif ($item_counts{to_be_replaced}) {
            $message .= "discard any labels and paperwork.";
        } else {
            $message .= "take any labels and paperwork to a packer.";
        }
    } elsif ($shipment->has_pigeonhole_items) {
        $message .= ". " if ($message);
        $message .= "Please return pigeon hole items to their original pigeon hole, place other items from shipment ".$shipment->id." back into the tote, place any labels in the tote and then place tote on the conveyor.";
    }

    xt_warn($err_message) if $err_message;
    xt_success($message) if $message;

    return $handler->redirect_to($redirect_default);
}

=head2 to_packing_message($item_counts, $shipment_id) : $message

Return user message for "Send to Packing".

=cut

sub to_packing_message {
    my ($item_counts, $shipment_id) = @_;

    my $use_induction_point = maybe_condition_config_var(
        "PackingException",
        "is_sent_to_packing_via_induction_point",
    );

    # in current XT instance has PRL enables direct users to Commissioner page to
    # perform following actions on shipment
    if ($use_induction_point) {
        return qq{Please go to the <a href="/Fulfilment/Commissioner">Commissioner}
            . qq{ page</a> to send the shipment $shipment_id to packing};
    }

    my $message = "Sent shipment $shipment_id to the commissioner ";

    if ($item_counts->{to_be_replaced} == 1) {
        $message .= "waiting for a replacement item";
    }
    elsif ($item_counts->{to_be_replaced} > 1) {
        $message .= "waiting for replacement items";
    }
    else {
        $message .= "ready to be sent to packer";
    }

    return $message;
}

=head2 replacement_message($item_counts, $shipment_id) : $message

Return user message for "Replacement will be sent to packer".

=cut

sub replacement_message {
    my ($item_counts, $shipment_id) = @_;
    my $plural = $item_counts->{to_be_replaced} == 1 ? "" : "s";
    return "Replacement item$plural for shipment $shipment_id will be sent directly to packer";
}

=head2 replacement_on_hold_message($item_counts, $items_out_of_stock, $shipment_id) : $message

Return user message for "Replacement is allocated, but it's on hold".

=cut

sub replacement_on_hold_message {
    my ($item_counts, $items_out_of_stock, $shipment_id) = @_;
    my $err_message = "";

    if ($item_counts->{in_stock} == 1) {
        $err_message = "A replacement has been allocated, but the ";
    }
    elsif ($item_counts->{in_stock} > 1) {
        $err_message = "Replacements have been allocated, but the ";
    }
    else {
        # no replacements available for the out-of-stock items
        $err_message = "The ";
    }

    if ($item_counts->{out_of_stock} == 1) {
        $err_message .= "following item does not have a replacement available in stock: "
            . $items_out_of_stock->[0]->get_true_variant->sku;
    }
    else {
        $err_message .= "following items do not have replacements available in stock: "
            . (join ', ', map {$_->get_true_variant->sku} @$items_out_of_stock);
    }

    $err_message .= ". Please alert Customer Care and ask them to take action. ";

    if ($item_counts->{picked} == 1) {
        $err_message .= "The remaining shipment item from $shipment_id sent to commissioner in 'on hold' status.";
    }
    elsif ($item_counts->{picked} > 1) {
        $err_message .= "The remaining shipment items from $shipment_id sent to commissioner in 'on hold' status.";
    }

    return $err_message;
}

1;


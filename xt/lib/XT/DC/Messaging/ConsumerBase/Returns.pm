package XT::DC::Messaging::ConsumerBase::Returns;
use NAP::policy qw(class tt);
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
use Data::Dump qw/pp/;
use XT::Domain::Returns;

use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;

use XTracker::Constants::FromDB qw/
  :renumeration_type
/;
use XT::DC::Messaging::Spec::Returns;
use XT::Business;
use XTracker::Config::Local qw( config_var );
use Clone       qw( clone );


sub base_route {
    return {
        'com.netaporter.messaging.support.returns.ReturnRequestMessage' => {
            code => \&return_request,
            spec => XT::DC::Messaging::Spec::Returns->return_request(),
        },
        return_request => {
            code => \&return_request,
            spec => XT::DC::Messaging::Spec::Returns->return_request(),
        },
        'com.netaporter.messaging.support.returns.CancelReturnItemsRequestMessage' => {
            code => \&cancel_return_items,
            spec => XT::DC::Messaging::Spec::Returns->cancel_return_items(),
        },
        cancel_return_items => {
            code => \&cancel_return_items,
            spec => XT::DC::Messaging::Spec::Returns->cancel_return_items(),
        },
    }
}


=head1 NAME

XT::DC::Messaging::ConsumerBase::Returns - base class for Return messages

=head1 DESCRIPTION

Due to the design of the webapp, order IDs are not unique across channels. It
was decided to encode the channel information in the queue name for returns,
C<dc1-nap-returns> and C<dc1-outnet-returns> (and similarly for dc2).

This base class exists so that we can have two controllers, one for each queue
that only change the action_namespace (which is the queue to subscribe to)
without needing to duplicate any code.

=cut

=head1 ATTRIBUTES

=head2 channel_id

=cut

has channel_id => (
    required => 1,
    is       => 'ro',
    isa      => 'Int'
);

=head2 should_capture_arma_errors

Flag to indicate that we should capture errors whilst processing the ARMA request.

=cut

has should_capture_arma_errors => (
    is          => 'rw',
    isa         => 'Bool',
    lazy_build  => 1,
);

=head2 raise_failure_for_any_line_item

Flag to indicate if one line item fails then fail the entire request.

=cut

has raise_failure_for_any_line_item => (
    is          => 'rw',
    isa         => 'Bool',
    lazy_build  => 1,
);

=head2 fulfilment_plugin

A Plugin used primarily for Fulfilment Only Channels (JC) to translate
the Third Party SKU into XT's version of it.

If a Channel doesn't have this Plugin then this Attribute will be 'undef'.

=cut

has fulfilment_plugin => (
    is => 'rw',
    isa =>'Object|Undef',
    lazy_build => 1,
);

=head2 internal_errors

Keep track of any Errors whilst processing the Request used in conjunction with
'should_capture_arma_errors' & 'raise_failure_for_any_line_item'.

=cut

has internal_errors => (
    is  =>'rw',
    isa => 'ArrayRef[Str]',
    traits => ['Array'],
    default => sub{ [] },
    handles => {
        add_internal_error => 'push',
        has_internal_error => 'count',
    },
);

=head2 channel

Channel Object for the 'channel_id'.

=cut

has channel => (
    is => 'ro',
    isa => 'Object',
    lazy_build => 1,
);


sub _build_channel {
    my ( $self ) = @_;

    my $channel = $self->model('Schema::Public::Channel')->find( $self->channel_id );

    return $channel;
}


sub _build_should_capture_arma_errors {
    my $self = shift;

    my $config_section = $self->channel->business->config_section;
    my $capture_errors = config_var('Returns_'.$config_section, 'should_capture_arma_errors') // 0;

    return $capture_errors;
}

sub _build_raise_failure_for_any_line_item {
    my $self = shift;

    my $config_section = $self->channel->business->config_section;
    my $raise_errors   = config_var('Returns_'.$config_section, 'raise_failure_for_any_line_item') // 0;

    return $raise_errors;
}

sub _build_fulfilment_plugin {
    my ($self) = @_;

    my $business_logic = XT::Business->new({ });

    return $business_logic->find_plugin($self->channel,'Fulfilment');
}

=head1 METHODS

=head2 return_request

=cut

sub return_request {
    my ($self, $message, $headers) = @_;

    my $org_msg = clone($message);
    my ($return, $order, $error);

    # make sure internal_error is empty to start with
    $self->internal_errors([]);

    try {
        my $txn = $self->model('Schema')->txn_scope_guard;

        my $order_info = $self->_extract_order_info($message);
        if (!$order_info){
            if( $self->should_capture_arma_errors ) {
                die "No Order Data Found\n";
            } else {
                return; # returns from the try
            }

        }

        my ($items,$notes) = $self->_process_return_items($message,$order_info);

        # If above has errors, then die
        if ( $self->has_internal_error && $self->raise_failure_for_any_line_item ) {
            die $self->internal_errors;
        }

        unless (keys %$items) {
            $self->log->warn("No usable line items found in RMA request. skipping");
            die "No usable line items found in RMA request \n" if $self->raise_failure_for_any_line_item;
            return; # returns from the try
        }

        my $params = {
            %$order_info,
            notes => $notes,
            items => $items,
        };

        ($return, $order) = @{$order_info}{qw/return order/};

        if ($return) {
            $self->_add_return_items($message,$params);
        }
        else {
            $return = $self->_create_return($message,$params);
        }

        $self->model('MessageQueue')->transform_and_send('XT::DC::Messaging::Producer::Orders::Update', { order => $order });
        $txn->commit;
    }
    catch {
        my $error = $_ // '';
        if( $self->should_capture_arma_errors && $self->can('process_failure') ) {
            $self->process_failure($org_msg, $headers, $error);
        } else {
            die $error;
        }
    };


    # Note: We allocate the shipment outside the transaction because
    # we need to ensure that the allocation will be available to the
    # amq consumer when it receives an allocate_response message.
    # See DCA-1458 for a better future plan.

    # Do not care about the error. It is just there so that the consumer doesn't fail.
    eval {
        if ($return && $return->exchange_shipment) {
            $return->exchange_shipment->allocate({
                factory => $self->model('MessageQueue'),
                operator_id => $APPLICATION_OPERATOR_ID,
            });
        }
    }

}

=head2 cancel_return_items

=cut

sub cancel_return_items {
    my ($self, $message, $headers) = @_;

    my $txn = $self->model('Schema')->txn_scope_guard;

    my $order_info = $self->_extract_order_info($message) or return;

    my ($return, $order, $ship) = @{$order_info}{qw/return order shipment/};

    unless ($return) {
        $self->log->warn(
            "Order ID @{[$order->id]} has no existing RMA to cancel." .
            " Ignoring cancel_return_items and sending order status message"
        );

        $self->model('MessageQueue')->transform_and_send('XT::DC::Messaging::Producer::Orders::Update', { order => $order });
        return;
    }
    my $ri_rs = $return->return_items->not_cancelled;

    # Remember whether IWS knows about shipment now, before we start cancelling shipment items
    my $exchange_shipment = $return->exchange_shipment;
    my $iws_knows = $exchange_shipment && $exchange_shipment->does_iws_know_about_me();

    my $items_to_cancel = {};
    for my $req ( @{$message->{returnItems}} ) {
        my $ri = $ri_rs->by_shipment_item( $req->{xtLineItemId} );

        unless ($ri) {
            $self->warn_skip_line_item("Unable to find return_item with xtLineItemId " . $req->{xtLineItemId},$order);
            next;
        }

        # Sanity check that the SKU sent to us matches
        unless ($ri->shipment_item->variant->sku eq $req->{sku}) {
            $self->warn_skip_line_item("SKU mismatch. Req: $req->{sku}. DB: " . $ri->shipment_item->variant->sku,$order);
            next;
        }

        next if $ri->is_cancelled;

        $items_to_cancel->{$ri->id} = $ri;
    }

    $self->log->debug("RI ids to cancel: @{[keys %$items_to_cancel]}");

    my $stock_manager = $ship->get_channel->stock_manager;
    # If we're cancelling all remaining return items, cancel the RMA instead of
    # just the items
    my $cancel_exchange;
    if (scalar(keys %$items_to_cancel) == $ri_rs->active_item_count) {
        $self->model('Returns')->cancel({
            return_id => $return->id,
            shipment_id => $ship->id,
            operator_id => $APPLICATION_OPERATOR_ID,
            send_default_email => 1,
            stock_manager => $stock_manager,
            notes => 'Return cancelled due to ARMA cancellation request from Website on ' . $message->{returnCancelRequestDate},
        });
    }
    else {
        $message->{refundType} ||= '';
        my @skus = map { $_->variant->sku } values %$items_to_cancel;
        my $skus_plural = ( @skus == 1 ? '' : 's' );
        $cancel_exchange = $self->model('Returns')->remove_items({
            return_id => $return->id,
            operator_id => $APPLICATION_OPERATOR_ID,
            return_items => { map { $_ => { remove => 1 } } keys(%$items_to_cancel) },
            send_default_email => 1,
            refund_type_id => (($message->{refundType}//'') eq 'CREDIT'
                            ? $RENUMERATION_TYPE__STORE_CREDIT
                            : $RENUMERATION_TYPE__CARD_REFUND),
            stock_manager => $stock_manager,
            notes => 'Return item' . $skus_plural . ' cancelled due to ARMA cancellation request from Website on ' . $message->{returnCancelRequestDate} . ' for SKU' . $skus_plural . ': ' . join( ',', @skus ),
        });
    }

    $self->model('MessageQueue')->transform_and_send('XT::DC::Messaging::Producer::Orders::Update', { order => $order });

    $stock_manager->commit;
    $txn->commit;

    # Send messages to IWS now that we have committed transaction
    $self->model('Returns')->send_msgs_for_exchange_items( $exchange_shipment )
        if $cancel_exchange && $iws_knows;

    # Re-allocating the shipment will ensure that a message is sent to the
    # relevant PRL, if required.
    if ($exchange_shipment) {
        $exchange_shipment->allocate({
            factory => $self->model('MessageQueue'),
            operator_id => $APPLICATION_OPERATOR_ID,
        });
    }
}

sub _extract_order_info {
    my ($self, $message) = @_;

    $self->log->debug("message is:\n" . pp($message));
    # First, find the order.
    my $order = $self->model('Schema::Public::Orders')->search({
        order_nr => $message->{orderNumber},
        channel_id => $self->channel_id
    })->first
      or die "Order $message->{orderNumber} was not found on channel @{[$self->channel->name]}\n";

    # RMA's are defined on shipments. Get the std class shipment
    my $ship = $order->get_standard_class_shipment
      or die "Order ID/Number @{[$order->id]}/$message->{orderNumber} does not have any standard class shipments\n";

    my $rmaNumber = $message->{rmaNumber} || '';

    my $return = $ship->returns->not_cancelled->first;

    if ($return && $return->rma_number ne $rmaNumber) {

        my $msg = "Order ID @{[$order->id]} has an existing RMA";
        if ($rmaNumber) {
            $msg = "Order ID @{[$order->id]} has an existing RMA " .
                   "@{[$return->rma_number]}, but the website sent $rmaNumber";
        }

        $self->log->warn(
            "$msg. Ignoring return_request and sending order status message"
        );

        # throw an error
        if( $self->should_capture_arma_errors ) {
            die "$msg\n";
        }

        $self->model('MessageQueue')->transform_and_send('XT::DC::Messaging::Producer::Orders::Update', { order => $order });
        return;
    }

    my $si_rs = $ship->shipment_items->not_cancelled;
    return {
        order => $order,
        shipment => $ship,
        return => $return,
        shipment_items => $si_rs,
    };
}

sub _create_return {
    my ($self, $message, $params) = @_;

    my ($ship, $items, $notes) = @{$params}{qw/shipment items notes/};


    $self->model('Returns')->create({
        shipment_id => $ship->id,
        return_request_date => exists $message->{returnRequestDate} ? $message->{returnRequestDate} :undef,
        operator_id => $APPLICATION_OPERATOR_ID,
        pickup => 0,
        return_items => $items,
        send_default_email => 1,
        notes => $notes,
        refund_type_id => (($message->{refundType}//'') eq 'CREDIT'
                        ? $RENUMERATION_TYPE__STORE_CREDIT
                        : $RENUMERATION_TYPE__CARD_REFUND)
    });
}

sub _add_return_items {
    my ($self, $message, $params) = @_;

    my ($ship, $items, $return, $notes) = @{$params}{qw/shipment items return notes/};

    $self->model('Returns')->add_items({
        return_id   => $return->id,
        shipment_id => $ship->id,
        operator_id => $APPLICATION_OPERATOR_ID,
        return_items => $items,
        send_default_email => 1,
        notes => $notes,
        refund_type_id => (($message->{refundType}//'') eq 'CREDIT'
                        ? $RENUMERATION_TYPE__STORE_CREDIT
                        : $RENUMERATION_TYPE__CARD_REFUND)
    });
}

sub _process_return_items {
    my ($self, $message, $params) = @_;

    my ($si_rs,$order) = @{$params}{qw/shipment_items order/};

    my $items = {};
    my @line_item_errors;

    my @notes = 'Created from Website request on ' . $message->{returnRequestDate};

    # Process the JSON and build up the info we need to pass to the Returns domain
    for my $req ( @{$message->{returnItems}} ) {
        my $si;
        if( exists $req->{externalLineItemId} ) {
            $si = $si_rs->search({ pws_ol_id => $req->{externalLineItemId} } )->first;
            $req->{xtLineItemId} = $si->id   if( $si );
        } else {
            $si = $si_rs->find( $req->{xtLineItemId} // 0 );
        }

        unless ($si) {
            my $line_item_id = defined $req->{externalLineItemId} ? $req->{externalLineItemId} : $req->{xtLineItemId};
            $line_item_id  //= 'undef';
            $self->warn_skip_line_item("Unable to find shipment_item with ID '${line_item_id}'", $order);
            $self->add_internal_error("Unable to find shipment_item with ID '${line_item_id}'");
            next;
        }


        my $original_sku = $req->{sku};
        my $schema = $self->model('Schema');
        if( $self->fulfilment_plugin ) {

            my $xt_sku = $self->fulfilment_plugin->call('get_xt_sku',$schema,  $req->{sku} ) ;
            $xt_sku //= '';

            if( $xt_sku ne '' ) {
                $req->{sku} = $xt_sku;
            } else {
                $self->warn_skip_line_item( $original_sku ." sku is not valid Third party sku", $order );
                $self->add_internal_error($original_sku ." sku is not valid Third party sku");
                next;
            }
        }

        # Sanity check that the SKU sent to us matches
        unless ($si->variant->sku eq $req->{sku}) {
            $self->warn_skip_line_item("SKU mismatch. Req: $original_sku. DB: " . $si->variant->sku,$order);
            $self->add_internal_error("SKU mismatch. Req: $original_sku. DB: " . $si->variant->sku);
            next;
        }

        # check for non-returnable item
        if( $si->is_not_returnable ) {
            $self->warn_skip_line_item("Non Returnable sku sent. Req: $original_sku. DB: " . $si->variant->sku,$order);
            $self->add_internal_error("Non Returnable sku sent. Req: $original_sku. DB: " . $si->variant->sku);
            next;

        }
        my $item = {};

        my $reason = $self->model('Schema::Public::CustomerIssueType')
                       ->return_reason_from_pws_code($req->{returnReason});

        unless ($reason) {
            $self->warn_skip_line_item("Unable to find reason from code " . $req->{returnReason},$order);
            $self->add_internal_error("Unable to find reason from code " . $req->{returnReason});
            next;
        }
        $item->{reason_id} = $reason->id;

        if (my $exch = $req->{exchangeSku}) {
            my $original_exsku = $exch;
            if( $self->fulfilment_plugin ) {
                my $xt_exch = $self->fulfilment_plugin->call('get_xt_sku', $schema, $req->{exchangeSku});
                if ( $xt_exch ne '' ) {
                    $exch = $xt_exch;
                    $req->{exchangeSku} = $xt_exch;
                } else {
                    $self->warn_skip_line_item( $original_exsku ." exchange sku is not valid third party sku", $order );
                    $self->add_internal_error($original_exsku ." exchange sku is not valid third party sku" );
                    next;
                }
            }

            $item->{type} = 'Exchange';
            my $exch_var = $si->variant->product->variants->find_by_sku($exch, { dont_die_when_cant_find => 1 } );

            if( ! $exch_var ) {
                $self->add_internal_error("Exchange SKU '$original_exsku' must be within same product as '$original_sku'");
                croak("Exchange SKU '$original_exsku' must be within same product as '$original_sku'");
            }

            $item->{exchange_variant} = $exch_var->id;

            # Sanity check
            unless ($exch_var && $exch_var->product_id == $si->variant->product_id) {
                $self->warn_skip_line_item("Exchange on @{[$req->{sku}]} to $exch couldn't find variant, " .
                                           "or its not for the right product", $order);
                $self->add_internal_error("Exchange on @{[$original_sku]} to $original_exsku couldn't find variant" );
                next;
            }
        }
        else {
            $item->{type} = 'Return';
        }

        $items->{$si->id} = $item;

        if (exists $req->{faultDescription} && length($req->{faultDescription})) {
          push @notes, $req->{sku} . ' - Fault Description: ' . $req->{faultDescription};
        }
    } #end of items loop


    return ( $items, join("\n", @notes) );
}

sub warn_skip_line_item {
    my ($self, $msg, $order) = @_;

    $self->log->warn(
        "Return request on Order ID @{[$order->id]}: ".
        $msg .
        ". Skipping this line item"
    );
}

package XT::DC::Messaging::Consumer::XTWMS;

=head1 NAME

XT::DC::Messaging::Consumer::XTWMS

=cut


use NAP::policy "tt", 'class';
use XT::DC::Messaging::Spec::WMS;
extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
with 'XT::DC::Messaging::ConsumerBase::LogReceipt';

use XTracker::Config::Local qw/config_var sys_config_var/;
use XTracker::Constants qw/
    $APPLICATION_OPERATOR_ID
/;
use XTracker::Constants::FromDB qw(
    :channel_transfer_status
    :customer_issue_type
    :flow_status
    :pws_action
    :shipment_class
    :shipment_hold_reason
    :shipment_item_status
    :shipment_status
    :stock_process_status
    :stock_process_type
    :variant_type
    :putaway_type
);
use XTracker::Database::StockProcess qw/get_putaway_type/;
use XTracker::Database::StockProcessCompletePutaway qw/complete_putaway/;
use XTracker::Database::Shipment qw( set_shipment_on_hold get_shipment_item_by_sku );
use XTracker::Database::Location qw( :iws );
use XTracker::Database::ChannelTransfer qw( complete_auto_channel_transfer );
use XTracker::Database::Recode;

use XTracker::Order::Printing::PremierShipmentInfo;
use XTracker::Order::Printing::PremierDeliveryNote;
use XTracker::Order::Printing::AddressCard;
use XTracker::WebContent::StockManagement;

use XT::JQ::DC;

use Data::Dump qw/pp/;
use XT::DC::Messaging::Spec::WMS;
use NAP::XT::Exception::Internal;

sub routes {
    return {
        destination => {
            stock_received => {
                code => \&stock_received,
                spec => XT::DC::Messaging::Spec::WMS->stock_received,
            },
            incomplete_pick => {
                code => \&incomplete_pick,
                spec => XT::DC::Messaging::Spec::WMS->incomplete_pick,
            },
            shipment_refused => {
                code => \&shipment_refused,
                spec => XT::DC::Messaging::Spec::WMS->shipment_refused,
            },
            picking_commenced => {
                code => \&picking_commenced,
                spec => XT::DC::Messaging::Spec::WMS->picking_commenced,
            },
            shipment_ready => {
                code => \&shipment_ready,
                spec => XT::DC::Messaging::Spec::WMS->shipment_ready,
            },
            ready_for_printing => {
                code => \&ready_for_printing,
                spec => XT::DC::Messaging::Spec::WMS->ready_for_printing,
            },
            moved_completed => {
                code => \&moved_completed,
                spec => XT::DC::Messaging::Spec::WMS->moved_completed,
            },
            tote_routed => {
                code => \&tote_routed,
                spec => XT::DC::Messaging::Spec::WMS->tote_routed,
            },
            inventory_adjust => {
                code => \&inventory_adjust,
                spec => XT::DC::Messaging::Spec::WMS->inventory_adjust,
            },
            stock_changed => {
                code => \&stock_changed,
                spec => XT::DC::Messaging::Spec::WMS->stock_changed,
            },
        },
    };
}

=head1 METHODS

=head2 stock_received

Stock Received, moved and refactored from complete putaway.

IWS sends this when it has completed putting new stock away. The
quantities can be different than the ones we sent in the
C<pre_advice>.

=cut

sub stock_received {
    my ($self, $message, $header) = @_;

    # do nothing if this is Ravni as all the updates have been done already
    return if $self->_iws_rollout_phase == 0;

    my $schema = $self->model('Schema')->schema;
    my $process_group_id = $message->{pgid};
    my $username = $message->{operator};
    my $operator = $self->_get_operator($schema,$username);

    if ($process_group_id =~ /^p/i) {
        $self->log->debug('Received stock_received for PGID: '.$process_group_id);
        $process_group_id =~ s/^p(utaway)?-//i;
    }
    elsif ($process_group_id =~ /^r/i) {
        $self->log->debug('Received stock_received for recode id: '.$process_group_id);
        # $process_group_id holds key to stock_recode table
        $self->_move_recoded_stock($schema,$message);
        return;
    }
    # We need the extra me because later we might need to call get_voucher
    # which will execute some related_resultset operations in some tables which
    # also have a status_id
    my $stock_process = $schema->resultset('Public::StockProcess')->search({
        "me.group_id" => $process_group_id,
        "me.status_id" => {'!=' => $STOCK_PROCESS_STATUS__PUTAWAY}
    },{
        order_by => ['id'],
    });

    return unless $stock_process->count;      # everything putaway, nothing to do.

    my $invar_location = $schema->resultset('Public::Location')->get_iws_location;
    die "No Invar location" unless $invar_location;

    # quantites sent from invar are authoritative. These will be used for the quantity table
    # xtracker stock_process.quantity will be used for logging. differences will be logged
    my $storage_type_rs = $schema->resultset('Product::StorageType');

    my $skip_storage_type = $stock_process->first->type_id == $STOCK_PROCESS_TYPE__FASTTRACK;

    $stock_process->reset;
    $schema->txn_do( sub {
        my %wms_remaining_for;
        for my $item (@{$message->{items}}) {

            my $variant = $self->_get_real_variant( $schema,$item->{sku});

            # Ensure client from message matches that for the sku in the db
            $self->_validate_sku_client($variant->sku(), $item->{client});

            $wms_remaining_for{$variant->id} += $item->{quantity};

            if (!$skip_storage_type) {
                # Vouchers are assumed to always be flat so no need to set storate type.
                next if $stock_process->get_voucher;
                my $storage_type_id = $storage_type_rs->by_name( $item->{storage_type} )->id;

                $variant->product->update({storage_type_id => $storage_type_id} );
            }
        }

        # Check if we're dealing with a Voucher
        # Currently, it seems, a voucher is always a 'Goods In' type
        # check process_voucher_sp@XTracker::Stock::GoodsIn::Putaway;
        # also, just has an added bonus, get_putaway_type can't handle Vouchers.

        my $putaway_type = $stock_process->get_voucher
            ? $PUTAWAY_TYPE__GOODS_IN
            : get_putaway_type($schema->storage->dbh, $process_group_id)->{putaway_type} // 0;

        my $putaway_ref = [];

        my %stock_processes_per_variant = ();
        push @{$stock_processes_per_variant{$_->variant->id}} , $_ for  $stock_process->all;

        foreach my $variant_id (keys %stock_processes_per_variant) {
            while (my $sp = shift @{$stock_processes_per_variant{$variant_id}}) {

                my $putaway = {
                    id          => $sp->id,
                    variant_id  => $variant_id,
                    quantity    => $sp->quantity,
                    location    => $invar_location->location,
                    location_id => $invar_location->id,
                    stock_process_type_id => $sp->type_id,
                };
                ## In the case we have more stock processes with the same variant id ,
                #  we assign to ext_quantity the sp->quantity to not have any discrepances.
                #  $wms_remaining_for{$variant_id} contains the sum of quantities from the message
                #  that have the same sku
                #  We than delete from the sum the quantity that was assigned.
                if (defined $wms_remaining_for{$variant_id}
                    && defined $sp->quantity && $wms_remaining_for{$variant_id} >= $sp->quantity){
                    $putaway->{ext_quantity} = $sp->quantity;
                    $wms_remaining_for{$variant_id} -= $sp->quantity;
                }
                else{
                    ## In case we have no quantity for a stock process in the received message
                    #  or the stock process quantity is bigger than the quantity in the message
                    $putaway->{ext_quantity} = $wms_remaining_for{$variant_id} // 0;
                    $wms_remaining_for{$variant_id} = 0;
                }

                ## In case we have discrepances so that total quantity for a sku in the message is
                #  bigger than the total stock_process quantity for that variant id
                #  assign the left over quantity to the last stock process of that variant id
                if (! scalar(@{$stock_processes_per_variant{$variant_id}}) ) {
                    if ($wms_remaining_for{$variant_id}) {
                        $putaway->{ext_quantity} += $wms_remaining_for{$variant_id};
                    }
                }

                if (   $putaway_type == $PUTAWAY_TYPE__RETURNS
                    || $putaway_type == $PUTAWAY_TYPE__STOCK_TRANSFER) {
                    my $ret_item = $sp->delivery_item->get_return_item;
                    $putaway->{return_item_id} = $ret_item->id;
                    $putaway->{shipment_id} = $ret_item->shipment_item->shipment_id;
                }

                $schema->resultset('Public::Putaway')->create({
                    stock_process_id => $putaway->{id},
                    location_id => $putaway->{location_id},
                    quantity => $putaway->{quantity},
                    complete => 0,
                });

               push @$putaway_ref, $putaway;
            }
        }
        my $msg_factory = $self->model('MessageQueue');
        complete_putaway( $schema, undef, $process_group_id, $operator->id, $msg_factory, $putaway_type, $putaway_ref );
    });
}

=head2 incomplete_pick

Received when IWS discovers after picking commences that it can not
fulfil the order. It implies a stock discrepancy, but we don't handle
it here: IWS will send a C<inventory_adjust> later.

=cut

sub incomplete_pick {
    my ($self, $message, $header) = @_;

    my ($shipment_id, $username) = @{$message}{qw/shipment_id operator/};
    $self->log->debug('Received incomplete_pick for shipment: '. $shipment_id);

    my $schema = $self->model('Schema')->schema;

    $shipment_id =~ s{^s(hipment)?-}{}i;

    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id)
        or die "Shipment with id $shipment_id not found in database!";
    my $operator = $self->_get_operator($schema,$username);

    my @items =
        sort { $a->{'sku'} cmp $b->{'sku'} }
        grep { $_->{'quantity'} }
        @{ $message->{'items'} };

    my $guard = $schema->txn_scope_guard;

    # Items are only used when using IWS
    if ($self->_iws_rollout_phase){
        foreach my $item (@items){

            # Ensure the sku exists and matches the client provided
            $self->_validate_sku_client($item->{'sku'}, $item->{'client'});

            my $shipment_item_id = get_shipment_item_by_sku($schema->storage->dbh,$shipment->id, $item->{'sku'});
            my $shipment_item = $schema->resultset('Public::ShipmentItem')->find($shipment_item_id);
            $shipment_item->update({is_incomplete_pick => 1});
        }
    }
    # we may want to ignore the incomplete pick message if the item they can't
    # pick has subsequently been cancelled. Or if @items is empty
    my $sis = $shipment->shipment_items;
    my @items_non_cancelled =
        grep { $sis->search_by_sku_and_item_status($_->{sku}, {'NOT IN' => [$SHIPMENT_ITEM_STATUS__CANCELLED, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING]})->count }
        @items;


    # Add a fulfilment note so CC can see what's missing
    my $missing_note = '';
    if (@items && !@items_non_cancelled){
        $self->log->warn("Incomplete pick message is only complaining about shipment items which have subsequently been cancelled. Inupuase and ignore it.");
        $self->model('MessageQueue')->transform_and_send( 'XT::DC::Messaging::Producer::WMS::ShipmentWMSPause', $shipment);
        return;
    } elsif ( @items ) {
        $missing_note =
            "The following " .
            ( ( @items == 1 && $items[0]->{'quantity'} == 1 ) ?
                'item was' : 'items were' ) .
            " missing:\n\n" .
            join "; ",
            map { $_->{'sku'} . ' x ' . $_->{'quantity'} }
            @items;
    } else {
        $missing_note = "No items found in incomplete pick message for shipment $shipment_id";
        $self->log->warn($missing_note);
    }

    if ($shipment->is_transfer_shipment){
        # We don't update the website as whilst for customer shipments they
        # go to return hold and later get cancelled, which increments the
        # pws stock by 1, here we do the cancellation directly, so we don't
        # need to update the pws
        $shipment->cancel(
            operator_id                 => $APPLICATION_OPERATOR_ID,
            customer_issue_type_id      => $CUSTOMER_ISSUE_TYPE__8__STOCK_DISCREPANCY,
            do_pws_update               => 0,
            only_allow_selected_items   => 1
        );
    } else {
        set_shipment_on_hold(
            $schema,
            $shipment_id,
            {
                status_id => $SHIPMENT_STATUS__HOLD,
                reason => $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK,
                operator_id => $operator->id,
                norelease => 1,
                comment => $missing_note
            });
    }
    $guard->commit;
    # This needs to be done outside of the transaction to prevent a race
    # condition (see $shipment->cancel pod)
    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::WMS::ShipmentCancel',
        { shipment => $shipment }
    ) if $shipment->is_transfer_shipment;
}

=head2 shipment_refused

Received when IWS knows up front that it will not be able to fulfil an order. Generally this
will be because XTracker and IWS inventories have drifted out of sync and XTracker believes that
there is stock available, but IWS does not.

The behaviour is different depending on whether the shipment is a customer order, or a sample shipment.

Unlike C<incomplete_pick>, we adjust the stock levels here directly.

In both cases for each unavailable items we
    * Decrement XTracker stock by <quantity> (this can result in negative stock)
    * Log the change
    * Update the web stock (first check that the product is live on website)

Then for customer shipments we
    * Put the shipment on hold (which emails various people by default)

Or for sample shipments
    * cancel sample shipment (including cancelling all shipment items)
    * cancel sample request
    * email sample team and inventory to tell them what we've done

=cut

sub shipment_refused {
    my ($self, $message, $header) = @_;

    # XXX TODO Find a home for this.
    my $reason = "IWS shipment_refused message";

    my $schema = $self->model('Schema')->schema;
    my $dbh = $schema->storage->dbh;

    my $shipment_id = $message->{shipment_id};
    $shipment_id =~ s/^s(?:hipment)?-//i;
    $self->log->debug("Consuming 'shipment_refused' message for shipment_id: $shipment_id");

    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id)
        or die "Shipment with id $shipment_id not found in database!";

    if ($shipment->is_pick_complete) {
        $self->log->warn("shipment_refused received on shipment ($shipment_id) that is pick complete, ignoring");
        return;
    }

    my $stock_status = $shipment->iws_stock_status();

    my $invar_location = $schema->resultset('Public::Location')->get_iws_location;
    my $comment = "shipment refused received from IWS\nunavailable sku (quantity)\n";
    my $channel = $shipment->get_channel;;
    my $stock_manager = $channel->stock_manager;

    # WHM-2808 Warehouse operations want shipment_refused message from IWS to
    # be allocated the 'hold reason' of "Failed Allocation". Also, XT does not
    # decrement stock when a shipment_refused message is received from IWS. The
    # discrepancies will be manually investigated and any stock adjustments
    # required will be done later.
    $schema->txn_do( sub {
        if ($shipment->is_sample_shipment){
            # We don't update the website as whilst for customer shipments they
            # go to return hold and later get cancelled, which increments the
            # pws stock by 1, here we do the cancellation directly, so we don't
            # need to update the pws
            $shipment->cancel(
                operator_id                 => $APPLICATION_OPERATOR_ID,
                customer_issue_type_id      => $CUSTOMER_ISSUE_TYPE__8__STOCK_DISCREPANCY,
                do_pws_update               => 0,
                only_allow_selected_items   => 1
            );
        } else {
            set_shipment_on_hold(
                $schema,
                $shipment_id,
                {
                    status_id => $SHIPMENT_STATUS__HOLD,
                    reason => $SHIPMENT_HOLD_REASON__FAILED_ALLOCATION,
                    operator_id => $APPLICATION_OPERATOR_ID,
                    norelease => 1,
                    comment => $comment,
                }
            );
        }
        $stock_manager->commit;
    });
    # This needs to be done outside of the transaction to prevent a race
    # condition (see $shipment->cancel pod)
    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::WMS::ShipmentCancel',
        { shipment => $shipment }
    ) if $shipment->is_sample_shipment;
}

=head2 picking_commenced

Self explanitory. We take no action at this point

=cut

sub picking_commenced {
    my ($self, $message, $header) = @_;
    $self->log->debug("Consuming 'picking_commenced' message for shipment id: ". $message->{shipment_id});
    return unless $self->_iws_rollout_phase;

    my $schema = $self->model('Schema')->schema;

    my $shipment_id = $message->{shipment_id};
    $shipment_id =~ s/^s(?:hipment)?-//i;

    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id)
        or die "Shipment with id $shipment_id not found in database!";

    my $operator = $self->_get_operator( $schema, $message->{operator} );

    my @cancelled_items = $shipment->search_related('shipment_items', {
         shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED
    })->all;

    my $channel = $shipment->get_channel;

    my $guard = $schema->txn_scope_guard;
    $shipment->update({is_picking_commenced => 1});
    $shipment->create_related('shipment_message_logs',{
        operator_id => $operator->id,
        message_type => 'WMS::PickingCommenced',
    });

    # Fix any items that are subject to a race condition where we cancel an
    # item after we send the picking_commenced message but before XTracker
    # receives it, which causes those items to be in a 'Cancelled' state when
    # they should be 'Cancel Pending'.
    my $stock_manager;
    eval {
        for my $item ( @cancelled_items ) {
            $item->set_cancel_pending( $APPLICATION_OPERATOR_ID );
            $stock_manager ||= $channel->stock_manager;
            # Adjust the web stock
            $stock_manager->stock_update(
                quantity_change => -1,
                variant_id      => $item->get_true_variant->id(),
                pws_action_id   => $PWS_ACTION__MANUAL_ADJUSTMENT,
                "notes"       =>
                    "Item picked before being cancellation took place; item awaiting return to Invar via QA desk",
            );
        }
        $stock_manager->commit if $stock_manager;
    };
    if (my $e = $@) {
        $stock_manager->rollback if $stock_manager;
        die $e;
    }
    $guard->commit;
}

=head2 shipment_ready

Received when picking is complete. Different behaviour depending on whether it is RAVNI or IWS sending the message.

Assuming the message comes from IWS for each shipment item in the message we need to:

=over 4

=item *

Set shipment items into "picked" state

=item *

Set C<container> values on shipment items

=item *

Decrement the quantity table for the IWS location

=item *

Then in some cases we need to print premier order stuff

=back

=cut

sub shipment_ready {
    my ($self, $message, $header) = @_;
    $self->log->debug("Consuming 'shipment_ready' message for shipment id: ". $message->{shipment_id});

    # do nothing if this is Ravni as all the updates have been done already
    return unless $self->_iws_rollout_phase;

    $message->{shipment_id} =~ s{^s(hipment)?-}{}i;

    my $schema   = $self->model('Schema')->schema;
    my $dbh      = $schema->storage->dbh;
    my $shipment = $schema->resultset('Public::Shipment')->find($message->{shipment_id})
        or die "Shipment with id $message->{shipment_id} not found in database!";

    my $operator = $self->_get_operator( $schema, $message->{operator} );

    my $invar_location = $schema->resultset('Public::Location')->get_iws_location;
    die "Cannot find Invar location in order to record picking of shipment " . $shipment->id
        unless $invar_location;

    my $stock_status = $shipment->iws_stock_status();

    # Determine which containers we have and haven't seen before
    # and produce a nice flat list of items
    my @all_items;
    $self->log->debug("Shipment ID [".$message->{shipment_id}."] has"
        . ( $shipment->container_ids
            ? " containers: ".join(', ', $shipment->container_ids)
            : " no containers"
        )
    );
    $self->log->debug("Message has ".scalar(@{$message->{containers}})." containers");
    for my $container_data ( @{$message->{containers}} ) {

        # wrap Container ID with NAP::DC::Barcode::Container, so we can use its
        # goodies down the line
        $container_data->{container_id} =
            NAP::DC::Barcode::Container->new_from_id(
                $container_data->{container_id},
            );

        my @container_items = map {
            my $item = $_;

            # Ensure the sku exists and matches the client provided
            $self->_validate_sku_client($item->{'sku'}, $item->{'client'});

            map { {
                sku => $item->{'sku'},
                container_id => $container_data->{'container_id'},
            } } (1 .. $item->{'quantity'})
        } @{$container_data->{'items'}};
        $self->log->debug("Message says container ".$container_data->{'container_id'}." has SKUs: "
            .join(', ', map { $_->{'sku'} } @{$container_data->{'items'}}));

        # Determine which containers we have seen before
        if (!grep { $container_data->{'container_id'} eq $_->id } $shipment->containers) {
            $self->log->debug("Adding items from container - first time we've seen it");
            push(@all_items, map { { %$_, seen_before => 0 } } @container_items);
        }
        else {
            $self->log->debug("Adding items from container - seen before");
            push(@all_items, map { { %$_, seen_before => 1 } } @container_items);
        }
    }

    # 'Canceled pending' items not mentioned in the 'shipment_ready' message
    # should become 'Cancelled', unless the shipment item was cancelled because
    # of a size change.

    # Get all info while everything is untouched:
    my @cancel_pending_sis = $shipment->shipment_items->search({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
    })->all; # Vouchers go straight to cancelled

    my @others_sis = $shipment->shipment_items->search({
        shipment_item_status_id => {'!=' => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING },
        variant_id => {'>' => 0} # Get rid of vouchers
    })->all;

    my %message_skus;
    $message_skus{$_->{sku}}++ for @all_items;
    foreach my $others_si (@others_sis){
        my $sku = $others_si->variant->sku;

        if (defined $message_skus{$sku}){
            $message_skus{$sku} --;
        }
    }

    # Assignment algorithm:
    #
    # 1. For each container, check that we know nothing about it. If we know
    #    anything about it, we must have already dealt with all the items in it
    #    - the rules say that any new items come in their own containers.
    #   ...except if the item has already been picked, then we do want to move
    #   it to a new container for GOH.
    #
    # 2. For each item in each remaining container, see if we have a shipment
    #    item in a selected state for it. If we do, pick that item in to the
    #    container.
    #
    # 3. If we have a cancel_pending item, also pick it.
    #
    # 4. If we have an already picked item, just update its container.
    my %si = (
        selected  => {},
        picked  => {},
        cancel_pending => {}
    );

    # Map out the remaining items we have
    for (
        [ selected          => $SHIPMENT_ITEM_STATUS__SELECTED  ],
        [ picked            => $SHIPMENT_ITEM_STATUS__PICKED ],
        [ cancel_pending    => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING ],
    ) {
        my ( $key, $status ) = @$_;

        push( @{$si{ $key }{ $_->get_sku }}, $_ ) for
            $shipment->shipment_items->search({
                shipment_item_status_id => $status
            })->all;
    }
    $self->log->debug("Found ".scalar(keys %{$si{$_ }//{}})." $_ items: ".join(', ', keys %{$si{$_}//{}}))
        for (keys %si);

    die "This message does not have any containers but the shipment has Selected shipment items"
        if (keys %{$si{'selected'}} && !scalar (@{$message->{containers}}));

    # Our move stock subref
    my $move_stock = sub {
        my $item = shift;
        my $to = shift;
        $schema->resultset('Public::Quantity')->move_stock({
            force           => 1,
            variant         => $item->get_true_variant->id,
            channel         => $shipment->get_channel->id,
            quantity        => 1,
            from            => {
                location => $invar_location,
                status   => $stock_status,
            },
            to              => $to,
            log_location_as => $operator,
        });
    };

    my $guard = $schema->txn_scope_guard;
    # Iterate over the items, picking or uncancelling as we go
    ITEM: foreach my $item ( @all_items ) {
        my $sku = $item->{sku};
        my $container_id = $item->{container_id};
        my $seen_before = $item->{seen_before};

        $self->log->debug("Dealing with SKU $sku in container $container_id"
            ." (".($seen_before ? "seen before" : "first time seen").")");

        # Pick items if we have a selected one
        if (my $pick_item = shift( @{$si{'selected'}{$sku}||[]} ) ) {
            $self->log->debug("Processing selected item");

            # Pick the item
            $pick_item->pick_into(
                $container_id, $operator->id,
                { dont_validate => 1 } # Trust Invar
            );

            # Update quantity table
            my $move_stock_to;
            # WHM-119: if it's a sample transfer, move to Transfer Pending so
            # it doesn't disappear until being booked into the Sample Room
            if ($shipment->shipment_class->id == $SHIPMENT_CLASS__TRANSFER_SHIPMENT) {
                $move_stock_to = {
                    location => $schema->resultset('Public::Location')->find({ location => 'Transfer Pending' }),
                    status => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                };
            }
            $move_stock->( $pick_item, $move_stock_to );

        }
        elsif (my $already_picked_item = shift( @{$si{'picked'}{$sku}||[]} ) ) {
            $self->log->debug("Processing picked item");

            # Only update the item's stored container ID.
            # This doesn't actually move the item anywhere, it just allows us
            # to collect together all the items that have the same container ID
            # stored against them (WHM-3662)
            $already_picked_item->pick_into(
                $container_id, $operator->id,
                { dont_validate => 1 } # Trust Invar
            );

        }
        elsif (my $cancel_pending_item = shift( @{$si{'cancel_pending'}{$sku}||[]} ) ) {
            $self->log->debug("Processing cancel_pending item");

           # Pick the item
           # Always update the item's stored container ID
           $cancel_pending_item->pick_into(
                $container_id, $operator->id,
                {
                    dont_validate => 1, # Trust Invar
                    status => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                },
            );

            if (! $seen_before) {
                # This only happens the first time we are told about the item

                # It should not happen a second time anyway because
                # Packing Exception should have dealt with the item
                # before XT receives another shipment_ready message.

                # Update quantity table
                $move_stock->( $cancel_pending_item );
            }
        }
    }

    ##'Canceled pending' items not mentioned in the 'shipment_ready' message should become 'Cancelled'
    #(unless the shipment item was cancelled because of a size change, so it does not have any containers)
    #  Cancel it here, so that it does not get overwritten!
    #
    foreach my $cancel_pending_si (@cancel_pending_sis){
        my $sku = $cancel_pending_si->variant->sku;
        next if $cancel_pending_si->container_id;
        if (defined $message_skus{$sku} && $message_skus{$sku} > 0){
            $message_skus{$sku} --;
        }
        else{
            $cancel_pending_si->update_status($SHIPMENT_ITEM_STATUS__CANCELLED,$operator->id);
        }
    }

    $shipment->discard_changes;
    if (!$shipment->is_pick_complete){
        # if not pick complete then either IWS is broken(!), or shipment
        # has changed and we need to unpause the shipment in IWS to
        # prompt them to get the new items

        $self->model('MessageQueue')->transform_and_send( 'XT::DC::Messaging::Producer::WMS::ShipmentWMSPause', $shipment);
    }
    $guard->commit;

    # check if pick complete and print out stuff for Premier orders
    if (config_var('Print_Document', 'requires_premier_nonpacking_printouts') &&
        $shipment->is_pick_complete &&
        $shipment->is_premier &&
        !$shipment->is_transfer_shipment
    ) {
        generate_premier_info($dbh, $shipment->id, "Premier Shipping", 1);
        generate_premier_delivery_note($dbh, $shipment->id, "Premier Shipping", 1);
    }

}

=head2 ready_for_printing

Received from IWS when they are ready to receive print docs for an order at the pick station

=cut

my %printer_doc_actions = (
    'Address Card' => sub {
        my %conf = %{$_[0]};

        # Lookup the printer name from the picking station ID
        my $printer = 'Picking Premier Address Card ' . $conf{'picking_station'};

        # Print the premier address card from the shipment
        generate_address_card(
            $conf{'dbh'},
            $conf{'shipment'}->id,
            $printer,
            1
        );

        return {
            printer_name => $printer,
            document     => 'Address Card',
        }
    },
    'MrP Sticker' => sub {
        my %conf = %{$_[0]};

        # Lookup the printer name from the picking station ID
        my $printer = 'Picking MRP Printer ' . $conf{'picking_station'};

        # Lookup the g-damn IP address. This printer code is not nice.
        # (Actually, this can be either a hostname or IP address)
        my $printer_address =
            sys_config_var( $conf{'schema'}, PackingPrinterList => $printer ) ||
            sys_config_var( $conf{'schema'}, PickingPrinterList => $printer ) ||
            warn "Couldn't find an IP for [$printer]";

        # Number to print
        my $item_count = $conf{'shipment'}->shipment_items->count();

        # Between August 2013 and June 2014, printing this sticker was
        #   sent off as a separate job to avoid blocking the consumer
        #   when the Zebra printers broke.
        #   See DCA-2710 / DCEA-1554
        # UPDATE: Now the Zebra printers work via XT::LP so we print
        #   directly again. See WHM-587
        $conf{'shipment'}->print_sticker( $printer_address, $item_count );

        return {
            printer_name => $printer,
            document     => 'MrP Sticker'
        }
    },
    'Gift Message' => sub {
        my %conf = %{$_[0]};

        my $shipment = $conf{'shipment'};

        return if (!$shipment->has_gift_messages());
        return if (!$shipment->can_automate_gift_message());

        my $config_section = $shipment->order->channel->business->config_section();
        my $printer = "Gift Card $config_section $conf{'picking_station'}";

        $shipment->print_gift_messages($printer);

        return {
            printer_name => $printer,
            document     => 'Gift Message'
        }
    }
);

sub ready_for_printing {
    my ($self, $message, $header) = @_;
    $self->log->debug("Consuming 'ready_for_printing' message with pick station: ".
        $message->{pick_station});

    # DB setup gubbins
    my $schema   = $self->model('Schema')->schema;
    my $dbh      = $schema->storage->dbh;

    # Get the matching shipment
    my $shipment_id = $message->{shipment_id};
    $shipment_id =~ s{^s(hipment)?-}{}i;
    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id)
        or die "Shipment with id $message->{shipment_id} not found in database!";

    # Get a list of documents to print
    my @docs_to_print = $shipment->list_picking_print_docs();

    # Print them
    my @printed = map {
        my $doc_name = $_;

        # Sanity check
        unless ( $printer_doc_actions{ $doc_name } ) {
            $self->log->warn("I don't know how to handle printer document [$doc_name]");
            next;
        }

        # Attempt to print. Stock up the goodies with anything that might
        # conceivably be required by our printer doc actions.
        my $conf = {
            shipment        => $shipment,
            picking_station => $message->{pick_station},
            dbh             => $dbh,
            schema          => $schema,
            operator        => $APPLICATION_OPERATOR_ID
        };
        my $print_report =
            $printer_doc_actions{ $doc_name }->( $conf );

        # Return the status
        $print_report;

    } @docs_to_print;

    # Turn the printer reports in to the return format. This is all pretty dull.
    my %printers_for_report;
    for my $report ( @printed ) {
        next if (!$report);
        # Make sure there's an array there if there wasn't
        $printers_for_report{ $report->{'printer_name'} } ||= [];
        # Add the printer report to it
        push( @{ $printers_for_report{ $report->{'printer_name'} } },
            $report->{'document'} );
    }
    my @printer_reports = map {
        {
            printer_name => $_,
            documents    => $printers_for_report{ $_ }
        }
    } keys %printers_for_report;

    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::WMS::PrintingDone',
        {
            'shipment_id' => $message->{'shipment_id'},
            'printers'    => \@printer_reports
        }
    );

}

=head2 moved_completed

A response to C<item_moved> message. We don't need to take any action.

=cut

sub moved_completed {
    my ($self, $message, $header) = @_;
    $self->log->debug("Consuming 'moved_completed' message with id: ". $message->{moved_id});
}

=head2 tote_routed

A response to C<route_tote> message. We don't need to take any action.

=cut

sub tote_routed {
    my ($self, $message, $header) = @_;
    $self->log->debug("Consuming 'tote_routed' message for tote: ". $message->{container_id});
}

=head2 inventory_adjust

Received from IWS to trigger an inventory adjust in XTracker when IWS discovers stock discrepancies
in its own inventory.

=cut

sub inventory_adjust {
    my ($self, $message, $header) = @_;

    my $schema=$self->model('Schema')->schema;

    $message->{location} = $schema->resultset('Public::Location')->get_iws_location;
    $message->{status} = $schema->resultset('Flow::Status')->find_by_iws_name( $message->{stock_status} );
    $message->{transit_status_id} = $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS;
    if (uc($message->{'reason'}) eq 'STOCK OUT TO XT') {
        $message->{'moving_to_transit'} = 1;
    }

    my $quantity = $schema->resultset('Public::Quantity')->adjust_quantity_and_log($message);

    $self->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::WMS::InventoryAdjusted',
        $quantity,
    );
}

=head2 stock_changed

A response to C<stock_change> message.

At the moment, we only send stock_change for channel transfers, so
we just need to complete the transfer.

=cut

sub stock_changed {
    my ($self, $message, $header) = @_;
    $self->log->debug("Consuming 'stock_changed' message for pid: ". $message->{what}->{pid});

    die "Missing pid" unless ($message->{what}->{pid});
    die "Invalid pid" unless ($message->{what}->{pid} =~ /^\d+$/);

    my $schema = $self->model('Schema')->schema;

    my $from_channel = $schema->resultset('Public::Channel')->find_by_name($message->{from}->{channel}, {
        ignore_case => 1,
    });
    die "Missing valid from channel" unless ($from_channel);
    my $to_channel = $schema->resultset('Public::Channel')->find_by_name($message->{to}->{channel}, {
        ignore_case => 1,
    });
    die "Missing valid to channel" unless ($to_channel);

    my $transfer_rs = $schema->resultset('Public::ChannelTransfer')->search({
        'product_id' => $message->{what}->{pid},
        'from_channel_id' => $from_channel->id,
        'to_channel_id' => $to_channel->id,
        'status_id' => $CHANNEL_TRANSFER_STATUS__SELECTED,
    });
    unless ($transfer_rs->count() == 1) {
        die "Didn't find exactly one matching channel transfer, so doing nothing";
    }
    my $operator = $self->_get_operator($schema,$message->{operator});
    complete_auto_channel_transfer($schema, $transfer_rs->first->id, $operator->id);

}

sub _get_operator {
    my ($self, $schema, $username) = @_;

    my $operator_rs = $schema->resultset('Public::Operator');
    my $operator;
    $operator   = $operator_rs->find({username => { -ilike => $username } }) if $username;
    $operator ||= $operator_rs->find( $APPLICATION_OPERATOR_ID );

    return $operator;
}

sub _get_real_variant {
    my ($self,$schema,$sku, $variant_type_id) = @_;

    # Check if it's a voucher
    my $voucher = $schema->resultset('Voucher::Variant')
    ->find_by_sku($sku,undef,1);

    return $voucher if $voucher;

    my $variant = $schema->resultset('Public::Variant')->find_by_sku( $sku,undef,1,$VARIANT_TYPE__STOCK );

    return $variant;
}

sub _iws_rollout_phase {
    return config_var('IWS', 'rollout_phase');
}

sub _move_recoded_stock {
    my ($self, $schema, $message) =  @_;

    my $recode_id = $message->{pgid};
    $recode_id =~ s/^r(ecode)?-//i;

    # Sergeant's log, Stardate 2012-07-27...
    #
    # We have cautiously entered the IWS Recode system in order to investigate
    # possibilites for reconciling it with the PRL Recode system. The IWS system
    # appears to disregard almost all of the information actually in a given
    # stock_recode entry, save the 'notes' field, and relies instead entirely on
    # the quantities returned in the incoming message from IWS. The stock_recode
    # field is set to /Completed/ for each set of items encountered.
    #
    # This limits our ability to sensibly refactor the code, so instead I have
    # instructed the crew to simply strip out the pieces which "increase XT
    # stock due to recode", put them in their own XTracker::Database::Recode
    # package, and then make this implementation follow that.
    #
    # Commander Data's neural network has been vacated. He has been returned to
    # us unharmed and, with the help of the nanites, our computer core has been
    # reconstructed in time for the experiment.

    # What ?
    my $stock_recode = $schema->resultset('Public::StockRecode')->find($recode_id);
    return unless $stock_recode;

    return if $stock_recode->complete;

    # We need to cross check payload quantities against the stock_recode table
    for my $item (@{$message->{items}}) {

        # Vouchers are never recoded
        my $variant = $schema->resultset('Public::Variant')->find_by_sku( $item->{sku});

        my $location = $schema->resultset('Public::Location');
        my $channel  = $variant->product->get_product_channel->channel;
        my $operator = $self->_get_operator($schema,$message->{operator});

        # This bit has been factored in to its own reusable hunka code
        if ( XTracker::Database::Recode::putaway_recode_via_variant_and_quantity({
            schema   => $schema,
            channel  => $channel,
            variant  => $variant,
            location => $location->get_iws_location,
            operator => $operator,
            notes    => $stock_recode->notes() || undef,
            quantity => $item->{'quantity'},
        }) ) {
            $stock_recode->update({ complete => 1 });
        }

    }

}

# Helper method to validate a client code supplied in a message against
# a sku
sub _validate_sku_client {
    my ($self, $sku, $message_client_code) = @_;

    my $schema = $self->model('Schema')->schema();

    # Ensure the sku exists and matches the client provided
    my $variant = $schema->resultset('Any::Variant')->find_by_sku($sku);
    NAP::XT::Exception::Internal->throw({
        message => 'SKU: ' . $sku . ' is unknown',
    }) unless $variant;

    # TODO: once IWS has been updated to always include the client this will become
    # manditory (WHM-2471)
    $variant->validate_client_code({
        client_code     => $message_client_code,
        throw_on_fail   => 1,
    }) if $message_client_code;

    return $variant;
}

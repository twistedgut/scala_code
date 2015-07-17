package XTracker::Stock::Actions::SetCancelPutAway;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Shipment qw( :DEFAULT );
use XTracker::Database::Product;
use XTracker::Database::Order qw( get_order_info );
use XTracker::Database::Stock qw( :DEFAULT check_stock_location );
use XTracker::Database::Logging qw( log_location );
use XTracker::Database::StockTransfer   qw( get_stock_transfer );
use XTracker::Constants::FromDB qw/ :pws_action
                                    :shipment_item_status
                                    :flow_status /;
use XTracker::Error;
use XTracker::WebContent::StockManagement;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

   my $view    = $handler->{param_of}{'view'} || '';
   $handler->{data}{view}  = "HandHeld"        if (uc($view) eq "HANDHELD");

    my $ret_params  = "";
    my $error_msg   = "";

    my $stock_manager;
    eval {
        CASE: {
            if (!$handler->{param_of}{'shipment_id'}) {
                $error_msg      = "No Shipment Id Passed";
            }
            if (!$handler->{param_of}{'sku'}) {
                $error_msg      = "No SKU Passed";
            }
            if (!$handler->{param_of}{'variant_id'}) {
                $error_msg      = "No Variant Id Passed";
            }
            if (!$handler->{param_of}{'location'}) {
                $error_msg      = "No Location Passed";
            }

            last CASE               if ($error_msg ne "");

            my $ship_info           = get_shipment_info( $dbh, $handler->{param_of}{shipment_id} );
            my $ship_items          = get_shipment_item_info( $dbh, $handler->{param_of}{shipment_id} );
            my $variant_id          = get_variant_by_sku( $dbh, $handler->{param_of}{sku} );
            my $stock_transfer;
            my $channel_id;

            if ( $ship_info->{orders_id} ) {
                my $order_info = get_order_info( $dbh, $ship_info->{orders_id} );
                $channel_id = $order_info->{channel_id};
            }
            else {
                my $stock_transfer_id   = get_shipment_stock_transfer_id( $dbh, $handler->{param_of}{shipment_id} );
                $stock_transfer         = get_stock_transfer( $dbh, $stock_transfer_id );
                $channel_id             = $stock_transfer->{channel_id};
            }

            my %pend_items;

            foreach my $ship_item_id ( keys %$ship_items ) {
                if ($ship_items->{$ship_item_id}{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING ){
                    $pend_items{$ship_items->{$ship_item_id}{variant_id}}   = $ship_item_id;
                }
            }

            if (!keys %pend_items) {
                $error_msg      = "There are no SKUs left for this Shipment";
            }

            if (!$variant_id || $handler->{param_of}{variant_id} != $variant_id || !$pend_items{$variant_id}) {
                $error_msg      = "The SKU entered does not match those waiting to be put away, please check and try again";
            }

            last CASE               if ($error_msg ne "");

            my $location = $schema->resultset('Public::Location')->find({
                location => $handler->{param_of}{location},
            });
            if ( !$location ){
                $error_msg  = "The location entered could not be found. Please try again";
                last CASE;
            } elsif ( !$location->allows_status($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS) ){
                $error_msg  = "The location entered was not a valid main stock location";
                last CASE;
            }

            my %args = (
                variant_id  => $handler->{param_of}{variant_id},
                location_id => $location->id,
                location    => $handler->{param_of}{location},
                quantity    => 1,
                type        => 'inc',
                action      => 9,
                operator_id => $handler->operator_id,
                notes       => $handler->{param_of}{shipment_id},
                channel_id  => $channel_id,
            );
            $args{$_.'status_id'} = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
                for qw/initial_ current_ next_/, '';

            my $is_located          = check_stock_location( $dbh, \%args );

            # Start our transaction when we start updating the db
            my $guard = $schema->txn_scope_guard;
            if( $is_located ){
                update_quantity( $dbh, \%args );
            }
            else{
                insert_quantity( $dbh, \%args );
            }

            # we don't log putaway for cancellations
            # as the item has not been packed yet

            ### shipment item status
            update_shipment_item_status( $dbh, $pend_items{$handler->{param_of}{variant_id}}, $SHIPMENT_ITEM_STATUS__CANCELLED );
            log_shipment_item_status( $dbh, $pend_items{$handler->{param_of}{variant_id}}, $SHIPMENT_ITEM_STATUS__CANCELLED, $handler->operator_id );

            # decrement transfer pending quantity for sample transfer shipments
            if ( $stock_transfer->{channel_id} ) {

                # check if transfer pending quantity exists
                my $transfer_quantity = get_stock_location_quantity( $dbh, {
                    variant_id  => $handler->{param_of}{variant_id},
                    location    => 'Transfer Pending',
                    channel_id  => $stock_transfer->{channel_id},
                    status_id   => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                });

                # decrement transfer pending location
                if ( $transfer_quantity > 0) {
                    update_quantity( $dbh, {
                        variant_id  => $handler->{param_of}{variant_id},
                        location    => 'Transfer Pending',
                        quantity    => -1,
                        type        => 'dec',
                        channel_id  => $stock_transfer->{channel_id},
                        current_status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                    });

                    # check if transfer pending location now 0 - delete it if it is
                    if ( $transfer_quantity == 1 ) {
                        delete_quantity( $dbh, {
                            variant_id  => $handler->{param_of}{variant_id},
                            location    => 'Transfer Pending',
                            channel_id  => $stock_transfer->{channel_id},
                            status_id   => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                        });

                        log_location( $dbh, {
                            variant_id  => $handler->{param_of}{variant_id},
                            location    => 'Transfer Pending',
                            channel_id  => $stock_transfer->{channel_id},
                            operator_id => $handler->operator_id,
                        });
                    }
                }
            } elsif ($ship_info->{orders_id}) {
                # its associated with an order so a customer order
                my $operator_id      = $handler->operator_id;
                my $variant_id       = $handler->{param_of}{'variant_id'};
                my $shipment_item_id = $pend_items{$variant_id};

                # Update shipment_item, disassociate item from container.
                my $si = $schema->resultset('Public::ShipmentItem')
                    ->find({ id => $shipment_item_id });
                $si->unpick;

                $stock_manager = XTracker::WebContent::StockManagement->new_stock_manager({
                    schema      => $schema,
                    channel_id  => $channel_id,
                });

                $stock_manager->stock_update(
                    quantity_change => '1',
                    variant_id      => $variant_id,
                    pws_action_id   => $PWS_ACTION__CANCELLATION,
                    operator_id     => $operator_id,
                    notes           => $si->cancelled_item->notes(),
                );
                $stock_manager->commit();
            }
            $guard->commit();
        }
    };
    if ($@) {
        $error_msg = $@;
        $stock_manager->rollback();
    }

    if ($error_msg ne "") {
        foreach ( keys %{$handler->{param_of}} ) {
            next            if ($_ eq "location" || $_ eq "submit");
            $ret_params     .= $_."=".$handler->{param_of}{$_}."&";
        }
        $ret_params .= "&view=$view";
        $ret_params     = "?".$ret_params               if ($ret_params ne "");
        xt_warn($error_msg);
        return $handler->redirect_to("/StockControl/Cancellations".$ret_params);
    }
    else {
        return $handler->redirect_to("/StockControl/Cancellations?view=$view");
    }
}

1;

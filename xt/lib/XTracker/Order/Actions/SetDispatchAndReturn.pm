package XTracker::Order::Actions::SetDispatchAndReturn;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database;
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Return;
use XTracker::Database::Invoice;
use XTracker::Database::Address;
use XTracker::Database::Logging qw( log_stock );

use XTracker::Utilities qw( parse_url url_encode number_in_list );

use XTracker::Constants         qw( :application );
use XTracker::Error;
use XTracker::Constants::FromDB qw( :stock_action :shipment_item_status :shipment_status :shipment_class :return_status :return_type :return_item_status :renumeration_class :renumeration_status :customer_issue_type :note_type :refund_charge_type );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);
    my $schema      = $handler->{schema};

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    # set up vars and get query string/form data
    my $redirect_url;
    my $order_id        = $handler->{param_of}{order_id};
    my $shipment_id     = $handler->{param_of}{shipment_id};
    my $refund_type_id  = $handler->{param_of}{refund_type_id};
    my $full_refund     = $handler->{param_of}{full_refund};


    eval {
        my $txn = $handler->{schema}->txn_scope_guard;
        my $dbh = $handler->{schema}->storage->dbh;

        # get all the info we need up front
        my $shipment = get_shipment_info( $dbh, $shipment_id );
        my $order = get_order_info( $dbh, $order_id );
        my $shipment_items = get_shipment_item_info( $dbh, $shipment_id );
        my $shipment_address = get_address_info( $dbh, $shipment->{shipment_address_id} );

        my $voucher_count       = 0;
        my $item_count          = 0;

        # set shipment status as dispatched
        update_shipment_status($dbh, $shipment_id, $SHIPMENT_STATUS__DISPATCHED, $handler->{data}{operator_id});

        # this can only happen while packing shipments with physical
        # items, so IWS knows about them
        $handler->msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentPacked', {
            shipment_id => $shipment_id,
            fake_dispatch => 1,
        });

        # update shipment item status as dispatched
        foreach my $shipment_item_id ( keys %{$shipment_items} ) {
            if ( number_in_list($shipment_items->{$shipment_item_id}{shipment_item_status_id},
                                $SHIPMENT_ITEM_STATUS__NEW,
                                $SHIPMENT_ITEM_STATUS__SELECTED,
                                $SHIPMENT_ITEM_STATUS__PICKED,
                                $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                $SHIPMENT_ITEM_STATUS__PACKED,
                            ) ) {

                $item_count++;
                my $ship_item   = $schema->resultset('Public::ShipmentItem')->find( $shipment_item_id );

                my $virtual_voucher = 0;
                if ( $shipment_items->{$shipment_item_id}{voucher} ) {
                    $voucher_count++;
                    if ( !$shipment_items->{$shipment_item_id}{is_physical} ) {
                        $virtual_voucher    = 1;
                    }
                }

                if ( $shipment_items->{$shipment_item_id}{voucher} ) {
                    # if a voucher then clear the voucher code

                    # de-activate the Voucher Code
                    $ship_item->unassign_and_deactivate_voucher_code;
                }

                $ship_item->update_status( $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                           $handler->{data}{operator_id} );
                $ship_item->unpick();

                # if item not packed yet (and not a Virtual Voucher) and not a re-shipment then log it in transaction log
                if ( number_in_list($shipment_items->{$shipment_item_id}{shipment_item_status_id},
                                    $SHIPMENT_ITEM_STATUS__NEW,
                                    $SHIPMENT_ITEM_STATUS__SELECTED,
                                    $SHIPMENT_ITEM_STATUS__PICKED,
                                    $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                )
                         && $shipment->{shipment_class_id} != $SHIPMENT_CLASS__RE_DASH_SHIPMENT && !$virtual_voucher ){
                    log_stock(
                        $dbh,
                        {
                            variant_id  => $shipment_items->{$shipment_item_id}{variant_id},
                            action      => $STOCK_ACTION__ORDER,
                            quantity    => -1,
                            operator_id => $handler->{data}{operator_id},
                            notes       => $shipment_id,
                            channel_id  => $order->{channel_id},
                         }
                    );
                }
            }
        }

        my $shipment_rs
            = $schema->resultset('Public::Shipment')->find( $shipment_id );

        # Broadcast the stock levels after changing the status above
        $shipment_rs->broadcast_stock_levels();

        # CREATE RETURN

        # get RMA number
        my $rma_number      = generate_RMA( $dbh, $shipment_id );
        my $tax_refund      = 0;

        # build data required for ARMA
        $handler->{data}{send_email}        = 0;
        $handler->{data}{refund_type_id}    = $refund_type_id;
        $handler->{data}{shipment_id}       = $shipment_id;
        $handler->{data}{pickup}            = 'false';
        $handler->{data}{rma_number}        = $rma_number;
        $handler->{data}{shipping_refund}   = $full_refund;
        $handler->{data}{dispatch_return}   = 1;

        my $ship_country    = get_dbic_country( $schema, $shipment_address->{country} );

        if ( $full_refund == 1
             || ( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX )
                || $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__DUTY ) ) ) {
            $tax_refund = 1;
        }


        # Only Return those Shipment Items that haven't been dispatched yet
        foreach my $shipment_item_id ( keys %{$shipment_items} ) {
            if ( number_in_list($shipment_items->{$shipment_item_id}{shipment_item_status_id},
                                $SHIPMENT_ITEM_STATUS__NEW,
                                $SHIPMENT_ITEM_STATUS__SELECTED,
                                $SHIPMENT_ITEM_STATUS__PICKED,
                                $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                $SHIPMENT_ITEM_STATUS__PACKED,
                            ) ) {
                my $tax     = 0;
                my $duty    = 0;

                if ( $tax_refund ) {
                    $tax    = $shipment_items->{$shipment_item_id}{tax};
                    $duty   = $shipment_items->{$shipment_item_id}{duty};
                }

                my $ship_item_data  = {
                    return          => 1,
                    type            => 'Return',
                    reason_id       => $CUSTOMER_ISSUE_TYPE__7__DISPATCH_FSLASH_RETURN,
                    full_refund     => ( $full_refund ? 1 : 0 ),
                    unit_price      => $shipment_items->{$shipment_item_id}{unit_price},
                    tax             => $tax,
                    duty            => $duty,
                };
                $handler->{data}{return_items}{$shipment_item_id}   = $ship_item_data;
            }
        }

        # use the ARMA stuff to create the Return and Communicate with the Web-Site
        my $return_domain   = $handler->domain('Returns');
        my $return  = $return_domain->create( $handler->{data} );

        # if the order contains only Gift Vouchers then cancel
        # the return as no return items will have been created
        if ( $voucher_count && ( $item_count == $voucher_count ) ) {
            if ( $return->return_items->count() == 0 ) {
                # move the invoice to 'Awaiting Action'
                my $invoice = $return->renumerations->first;
                $invoice->update_status( $RENUMERATION_STATUS__AWAITING_ACTION, $handler->{data}{operator_id} );

                # update the Return Status to be 'Cancelled'
                $return->update_status( $RETURN_STATUS__CANCELLED, $handler->{data}{operator_id} );

                # Update Shipment Status to be Cancelled
                $return->shipment->update_status( $SHIPMENT_STATUS__CANCELLED, $handler->{data}{operator_id} );

                # Add a note explaining what's going on
                $return->shipment->create_related( 'shipment_notes', {
                                                            # use APP OP ID so that it can't be edited or deleted
                                                            operator_id => $APPLICATION_OPERATOR_ID,
                                                            note_type_id=> $NOTE_TYPE__SHIPPING,
                                                            date        => \"now()",
                                                            note        => "Dispatch/Return: Shipment contained only Gift Vouchers and so each item was Canceled along with the Shipment itself the Refund Invoice was set to 'Awaiting Action'. An empty Return was also created and then immediately Canceled.",
                                                        } );
            }
        }

        $txn->commit;
    };

    if ($@) {
        xt_warn("An error occured trying to Dispatch and Return the shipment:<br />$@");
        $redirect_url = $short_url.'/DispatchAndReturn?order_id='.$order_id.'&shipment_id='.$shipment_id;
    }
    else {
        xt_success('Dispatch and Return completed successully.');
        $redirect_url = $short_url.'/OrderView?order_id='.$order_id;
    }

    return $handler->redirect_to( $redirect_url );
}

1;


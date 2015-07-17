package XTracker::Order::Fulfilment::ScanFaultyItem;
use strict;
use warnings;
use Try::Tiny;

use XTracker::Handler;
use XTracker::Utilities             qw( strip );
use XTracker::Constants::FromDB     qw(
    :container_status
    :flow_status
    :packing_exception_action
    :pws_action
    :rtv_action
    :shipment_item_status
    :stock_action
);
use XTracker::Error;
use XTracker::Database              qw( get_database_handle );
use XTracker::Database::Stock::Quarantine  qw( :quarantine_stock );
use XTracker::Database::Container   qw( :utils :validation );
use NAP::DC::Barcode::Container;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my ($shipment_id,$shipment_item_id,$container_id)=strip($handler->{param_of}{shipment_id},
                                                            $handler->{param_of}{shipment_item_id},
                                                            $handler->{param_of}{container_id});

    unless ($shipment_id) {
        xt_warn("No shipment ID");

        return $handler->redirect_to("/Fulfilment/PackingException");
    }

    my $check_shipment_url="/Fulfilment/Packing/CheckShipmentException?shipment_id=$shipment_id";

    unless ($shipment_item_id) {
        xt_warn("No ID for the item to be scanned");

        return $handler->redirect_to($check_shipment_url);
    }

    my $schema=$handler->{schema};

    my $faulty_item=$schema->resultset('Public::ShipmentItem')->find($shipment_item_id);

    unless ($faulty_item) {
        xt_warn("Cannot locate shipment_item with ID $shipment_item_id");

        return $handler->redirect_to($check_shipment_url);
    }

    unless ($container_id) {
        xt_warn("No ID for the target container");
        return $handler->redirect_to($check_shipment_url);
    }

    my $err;
    try {
        $container_id = NAP::DC::Barcode::Container->new_from_id($container_id);
        $err = 0;
    } catch {
        xt_warn("That container ID is invalid");
        $err = 1;
    };
    return $handler->redirect_to($check_shipment_url) if $err;

    my $container=get_container_by_id($handler->{schema},$container_id);

    unless ($container && ($container->accepts_faulty_items || $container_id->is_type('pigeon_hole') )) {
        xt_warn("May not use that container for faulty items; please scan another");

        return $handler->redirect_to($check_shipment_url);
    }

    try {
        # so, as of now, we:
        #
        #  + remove the item from its container
        #  + trash its QC Failure reason
        #  + put it into status 'NEW' (so that we know it's been handled at PX)
        #       (or in phase > 0 we put it into status 'SELECTED')
        #  + create a duplicate of it in location 'Quarantine' (so we don't lose track of the broken one)
        #  + check that the container ID we've been given can accept a faulty item
        #    (available or packing exception?)
        #  + send an 'item_moved' message to IWS incriminating that container,
        #    but don't actually put the item in the container
        #
        $schema->txn_do (
            sub {
                my $dbh         = $handler->{dbh};
                my $operator_id = $handler->operator_id;

                # capture a bunch of item-specific details that we need later
                my $old_container_id = $faulty_item->container_id;
                my $variant          = $faulty_item->get_true_variant;
                my $channel          = $faulty_item->get_channel;
                my $faulty_notes =
                    'Faulty: '.($faulty_item->qc_failure_reason||'No reason given');

                # disassociate the item from its container
                $faulty_item->unpick;

                my $item_cancelled = 0;

                # now renew the item
                my $si_status;
                if ( $faulty_item->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING ) {
                    $si_status = $SHIPMENT_ITEM_STATUS__CANCELLED;
                    $item_cancelled++;
                } else {
                    $si_status = $handler->iws_rollout_phase
                               ? $SHIPMENT_ITEM_STATUS__SELECTED
                               : $SHIPMENT_ITEM_STATUS__NEW;
                }
                $faulty_item->update_status(
                    $si_status, $operator_id, $PACKING_EXCEPTION_ACTION__FAULTY
                );
                $faulty_item->update({qc_failure_reason => undef });

                # don't move or log vouchers, they're just destroyed
                unless ($faulty_item->is_voucher) {
                    move_faulty_to_quarantine( $dbh, {
                                            variant_id => $variant->id,
                                            channel_id => $channel->id,
                                            quantity => 1,
                                            notes => $faulty_notes,
                                            location => 'Packing Exception',
                                         } );

                    log_quarantined_stock( $dbh, {
                                            variant_id => $variant->id,
                                            channel_id => $channel->id,
                                            operator_id => $operator_id,
                                            quantity => 1,
                                            stock_action => $STOCK_ACTION__QUARANTINED,
                                            notes => $faulty_notes,
                                            rtv_log_notes => 'Faulty at Packing Exception; moved to Quarantine',
                                            rtv_action => $RTV_ACTION__QUARANTINED,
                                         } );
                }
                if (! $item_cancelled ) {
                    adjust_quarantined_web_stock( $dbh, {
                        variant_id => $variant->id,
                        channel_id => $channel->id,
                        operator_id => $operator_id,
                        pws_action => $PWS_ACTION__QUARANTINED,
                        notes => $faulty_notes,
                        quantity => 1
                    } );
                }
                # at present, IWS just ignores this -- by phase 3, it shouldn't
                # be needed (or sent), as IWS will do faulty processing directly
                if ($container_id->is_type('pigeon_hole')) {
                    # for pigeon holes, we pretend it's gone to a fake tote
                    $handler->msg_factory->transform_and_send(
                        'XT::DC::Messaging::Producer::WMS::ItemMoved',
                        {
                            shipment_id => $shipment_id,
                            from  => { $old_container_id ?
                                ( container_id => $old_container_id ) :
                                ( 'no' => 'where' )
                            },
                            to    => { container_id => 'M01',
                                       stock_status => 'faulty' },
                            items => [{
                                sku      => $faulty_item->get_sku,
                                quantity => 1,
                                client   => $faulty_item->get_client()->get_client_code(),
                            },],
                        }
                    );
                } else {
                    $handler->msg_factory->transform_and_send(
                        'XT::DC::Messaging::Producer::WMS::ItemMoved',
                        {
                            shipment_id => $shipment_id,
                            from  => { $old_container_id ?
                                ( container_id => $old_container_id ) :
                                ( 'no' => 'where' )
                            },
                            to    => { container_id => $container_id,
                                       stock_status => 'faulty' },
                            items => [{
                                sku      => $faulty_item->get_sku,
                                quantity => 1,
                                client   => $faulty_item->get_client()->get_client_code(),
                            },],
                        }
                    );
                }
            }
        );

        xt_success("Successfully moved faulty item with SKU ".$faulty_item->get_sku." to quarantine");
    }
    catch {
        xt_warn($_);
    };

    return $handler->redirect_to($check_shipment_url);
}

1;

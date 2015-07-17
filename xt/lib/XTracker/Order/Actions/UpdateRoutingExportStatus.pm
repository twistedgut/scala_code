package XTracker::Order::Actions::UpdateRoutingExportStatus;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Handler;
use XTracker::Database;
use XTracker::Database::Shipment;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::Routing qw( update_routing_export_status get_routing_export_shipment_list );

use XTracker::Constants::FromDB qw( :shipment_status :shipment_item_status );

use XTracker::Utilities qw( number_in_list );

use XTracker::Error;

sub handler {
    my $r = shift;
    my $handler = XTracker::Handler->new($r);

    my $routing_export_id   = $handler->{request}->param('routing_export_id');
    my $status              = $handler->{request}->param('status');

    my $operator_id = $handler->operator_id;

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    eval {

        # flag to track if all dispatches were completed
        my $dispatch_complete = 1;

        my $guard = $schema->txn_scope_guard;
        ### extra step for manifest completion - dispatch all shipments in manifest
        if ($status eq "Complete") {

            # get all shipments from manifest
            my $shipments = get_routing_export_shipment_list( $dbh, $routing_export_id );

            my $dispatch_schema = XTracker::Database->xtracker_schema_no_singleton;

            # loop through and dispatch them all
            foreach my $shipment_id ( keys %{ $shipments } ) {

                if ($shipments->{$shipment_id}{status} eq "Processing") {

                    ### get data we need to dispatch shipment
                    my $data;

                    $data->{shipment_info}  = get_shipment_info( $dbh, $shipment_id );
                    $data->{shipment_items} = get_shipment_item_info( $dbh, $shipment_id );
                    $data->{order_id} = get_shipment_order_id($dbh, $shipment_id);
                    $data->{order_info} = get_order_info($dbh, $data->{order_id});

                    # flag to indicate of shipment is at the correct stage for dispatch
                    my $dispatch_ok = 1;

                    # check shipment status
                    if ( $data->{shipment_info}{shipment_status_id} != $SHIPMENT_STATUS__PROCESSING ) {
                        $dispatch_ok = 0;
                    }

                    # check item status is correct for dispatch
                    # may not have finished packing yet
                    foreach my $item_id ( keys %{$data->{shipment_items}} ) {
                        if ( number_in_list($data->{shipment_items}{$item_id}{shipment_item_status_id},
                                            $SHIPMENT_ITEM_STATUS__NEW,
                                            $SHIPMENT_ITEM_STATUS__SELECTED,
                                            $SHIPMENT_ITEM_STATUS__PICKED,
                                            $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                        ) ) {
                            $dispatch_ok = 0;
                        }
                    }

                    # dispatch shipment
                    if ( $dispatch_ok == 1) {
                        eval {
                            $dispatch_schema->txn_do(sub{
                                dispatch_shipment($dispatch_schema, $data, $operator_id);
                            });
                            update_website($handler,$schema,$shipment_id);
                        };
                        if ( my $err = $@ ) {
                            xt_warn( "Error Dispatching Shipment: $shipment_id \n${err}" );
                        }

                    }
                    # incorrect status for dispatch
                    else {
                        # if shipment not dispatched already unset the completion flag
                        # we don't want to set export status to complete yet
                        if ( $data->{shipment_info}{shipment_status_id} != $SHIPMENT_STATUS__DISPATCHED ) {
                            $dispatch_complete = 0;
                        }
                    }
                }
            }
        }

        # update export status if dispatch completed
        if ( $dispatch_complete == 1 ) {
            update_routing_export_status($dbh, $routing_export_id, $status, $operator_id);
        }

        $guard->commit();
    };
    if ( my $err = $@ ) {
        xt_warn($err);
    }

    return $handler->redirect_to("Fulfilment/PremierRouting?routing_export_id=$routing_export_id");
}

sub update_website {
    my ($handler,$schema,$shipment_id)=@_;
    eval {
        my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);
        $handler->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::Orders::Update',
            { order_id => $shipment->order->id }
        );
    };
    if($@) {
        xt_warn( $@ );
    }
}

1;


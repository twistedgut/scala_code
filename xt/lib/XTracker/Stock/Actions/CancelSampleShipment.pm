package XTracker::Stock::Actions::CancelSampleShipment;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Shipment        qw( get_shipment_info get_shipment_item_info update_shipment_status );
use XTracker::Constants::FromDB         qw( :customer_issue_type :pws_action :shipment_status );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new(shift );

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    my $shipment_id    = $handler->{param_of}{shipment_id};
    my $shipment_info  = get_shipment_info( $dbh, $shipment_id );
    my $shipment_items = get_shipment_item_info( $dbh, $shipment_id );

    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

    my $redirect = '/StockControl/Sample';

    unless ( $shipment->is_processing ) {
        xt_warn("Shipment must have the status of 'Processing' to be cancelled, current status is $shipment_info->{shipment_status}");
        return $handler->redirect_to($redirect);
    }

    if ( $shipment->is_shipment_completely_packed ) {
        xt_warn("Shipment $shipment_id cannot be cancelled as it has already been packed");
        return $handler->redirect_to($redirect);
    }

    # We need to store this value *before* cancelling the shipment
    my $to_send = $shipment->does_iws_know_about_me;
    my $stock_manager = $shipment->get_channel->stock_manager;
    eval {$schema->txn_do(sub{
        # first cancel re-shipment
        update_shipment_status( $dbh, $shipment_id, $SHIPMENT_STATUS__CANCELLED, $handler->{data}{operator_id} );

        # update items and log status
        foreach my $item_id ( keys %{ $shipment_items } ) {
            $schema->resultset('Public::ShipmentItem')->find($item_id)->cancel({
                operator_id => $handler->operator_id,
                pws_action_id => $PWS_ACTION__CANCELLATION,
                customer_issue_type_id => $CUSTOMER_ISSUE_TYPE__8__OTHER,
                stock_manager => $stock_manager,
            });
        }

        if ( $to_send ) {
            $handler->msg_factory->transform_and_send( 'XT::DC::Messaging::Producer::WMS::ShipmentCancel',
                { shipment_id => $shipment_id},
            );
        }
        $stock_manager->commit;
    });};

    if ($@) {
        $stock_manager->rollback;
        xt_warn("An error occured whilst trying to cancel the shipment: <br />$@");
    }
    else {
        xt_success('Sample shipment cancelled');
    }

    return $handler->redirect_to( $redirect );
}

1;

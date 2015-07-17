package XTracker::Order::Actions::SetCancelReshipment;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Shipment;

use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :shipment_status :shipment_item_status :shipment_class );
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my $redir_form  = 0;

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $shipment_id = $handler->{param_of}{shipment_id};
    my $order_id    = $handler->{param_of}{order_id};
    my $redirect    = $short_url.'/OrderView?order_id='.$order_id;

    # shipment id in post vars?
    if ( $shipment_id ) {

        eval {

            my $schema = $handler->schema;
            my $dbh = $schema->storage->dbh;
            my $guard = $schema->txn_scope_guard;
            # get re-shipment data
            my $shipment_info       = get_shipment_info( $dbh, $shipment_id );
            my $shipment_items      = get_shipment_item_info( $dbh, $shipment_id );

            # get the all shipments tied to the order
            my $shipments = get_order_shipment_info( $dbh, $order_id );

            # first cancel re-shipment
            update_shipment_status( $dbh, $shipment_id, $SHIPMENT_STATUS__CANCELLED, $handler->{data}{operator_id} );

            # update items and log status
            foreach my $item_id ( keys %{ $shipment_items } ) {
                update_shipment_item_status( $dbh, $item_id, $SHIPMENT_ITEM_STATUS__CANCELLED );
                log_shipment_item_status( $dbh, $item_id, $SHIPMENT_ITEM_STATUS__CANCELLED, $handler->{data}{operator_id} );
            }


            # now reset original item status back to dispatched
            foreach my $ship_id ( keys %{ $shipments } ) {
                if ( $shipments->{ $ship_id }{ shipment_class_id } == $SHIPMENT_CLASS__STANDARD ) {
                    my $items = get_shipment_item_info( $dbh, $ship_id );
                    foreach my $item_id ( keys %{ $items } ) {
                        if ( $items->{ $item_id }{ shipment_item_status_id } == $SHIPMENT_ITEM_STATUS__UNDELIVERED ) {
                            update_shipment_item_status( $dbh, $item_id, $SHIPMENT_ITEM_STATUS__DISPATCHED );
                            log_shipment_item_status( $dbh, $item_id, $SHIPMENT_ITEM_STATUS__DISPATCHED, $handler->{data}{operator_id} );
                        }
                    }
                }
            }

            $guard->commit();
            xt_success("Re-Shipment Cancelled");
        };

        if ($@) {
            if ( !$redir_form ) {
                xt_warn("An error occurred whilst cancelling the shipment:<br />$@");
            }
        }

    }

    return $handler->redirect_to( $redirect );
}

1;

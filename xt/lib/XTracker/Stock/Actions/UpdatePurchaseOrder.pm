package XTracker::Stock::Actions::UpdatePurchaseOrder;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Database::PurchaseOrder qw( update_purchase_order set_shipping_window );
use XTracker::Error;
use XTracker::Logfile 'xt_logger';

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    # form submitted
    if ( $handler->{param_of}{purchase_order_number} ){

        my $schema = $handler->schema;

        # Check if this specific PO is editable here, otherwise bail out
        my $purchase_order = $schema->resultset('Public::PurchaseOrder')->find( $handler->{param_of}{po_id} );

        # TODO: Surely this is a bug? It returns nothing, the app is expecting
        # a response of some sort. Logging to if/when we hit this.
        if ( $purchase_order && !$purchase_order->is_editable_in_xt ) {
            xt_logger->warn( join q{ },
                "Purchase order is $handler->{param_of}{po_id}, not editable in XT.",
                'Returning nothing, this is weird. Speak to prodman I think.'
            );
            return;
        }

        eval {

            # updating PO details
            my $po_id       = $handler->{param_of}{po_id};
            my $season_id   = $handler->{param_of}{season};
            my $act_id      = $handler->{param_of}{act};
            my $description = $handler->{param_of}{description};
            my $placed_by   = $handler->{param_of}{placed_by};

            my $dbh = $schema->storage->dbh;
            my $guard = $schema->txn_scope_guard;
            if ( $po_id && $season_id && $act_id ) {
                # update po details
                update_purchase_order(
                                        $dbh,
                                        $po_id,
                                        {
                                            'season_id' => $season_id,
                                            'act_id' => $act_id,
                                            'description' => $description,
                                            'placed_by' => $placed_by
                                        }
                );
            }

            # updating shipping window on Stock Orders
            my $start_ship_date;
            my $cancel_ship_date;

            if ( $handler->{param_of}{start_ship_year} && $handler->{param_of}{start_ship_month} && $handler->{param_of}{start_ship_day} ) {
                $start_ship_date = $handler->{param_of}{start_ship_year} .'-'. $handler->{param_of}{start_ship_month} .'-'. $handler->{param_of}{start_ship_day};
            }

            if ( $handler->{param_of}{cancel_ship_year} && $handler->{param_of}{cancel_ship_month} && $handler->{param_of}{cancel_ship_day} ) {
                $cancel_ship_date = $handler->{param_of}{cancel_ship_year} .'-'. $handler->{param_of}{cancel_ship_month} .'-'. $handler->{param_of}{cancel_ship_day};
            }

            if ( $start_ship_date && $cancel_ship_date) {
                # set shipping window
                set_shipping_window( $dbh, $po_id, { 'start_ship_date' => $start_ship_date, 'cancel_ship_date' => $cancel_ship_date } );
            }
            $guard->commit();
            xt_success('Purchase Order successfully updated');
        };

        if ($@) {
            xt_warn('An error occured whilst trying to update the Purchase Order: '. $@);
        }
    }
    return $handler->redirect_to( '/StockControl/PurchaseOrder/Edit?po_id=' .$handler->{param_of}{po_id} );

}

1;

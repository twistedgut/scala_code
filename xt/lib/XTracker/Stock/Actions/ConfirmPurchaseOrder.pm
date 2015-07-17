package XTracker::Stock::Actions::ConfirmPurchaseOrder;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Stock         qw( confirm_stock_order unconfirm_stock_order );
use XTracker::Database::PurchaseOrder qw( confirm_purchase_order );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    # form submitted
    if ( $handler->{param_of}{po_id} ){

        eval {

            my $schema = $handler->schema;
            my $dbh     = $schema->storage->dbh;

            # updating PO details
            my $po_id           = $handler->{param_of}{po_id};
            my $po_confirmed    = $handler->{param_of}{po_confirmed};
            my $confirmcomplete = $handler->{param_of}{confirmcomplete};

            my $guard = $schema->txn_scope_guard;
            # confirm purchase order
            if ( $po_confirmed && $confirmcomplete ) {
                confirm_purchase_order( { dbh => $dbh, purchase_order_id => $po_id, operator_id => $handler->{data}{operator_id} } );
            }

            # unconfirm / confirm stock orders

            # arrays to store what to update
            my ( @stock_order_ids_confirm, @stock_order_ids_unconfirm );

            # loop over form to get what we need to update
            foreach my $form_key ( %{ $handler->{param_of} } ) {

                # match confirmation form fields
                if( $form_key =~ m/(.*confirmed)_(\d+)/ ){

                    # get status and stock order item id out of form field
                    my ( $status, $soi_id ) = ( $1, $2 );

                    if ( $status eq 'unconfirmed' ) {
                        push @stock_order_ids_unconfirm, $soi_id;
                    }

                    if ( $status eq 'confirmed' && $handler->{param_of}{$form_key} eq 'on' ) {
                        push @stock_order_ids_confirm, $soi_id;
                    }

                }
            }

            unconfirm_stock_order( { dbh => $dbh, stock_order_ids => \@stock_order_ids_unconfirm } );
            confirm_stock_order( { dbh => $dbh, stock_order_ids => \@stock_order_ids_confirm } );

            $guard->commit();
            xt_success('Confirmations successfully updated');
        };

        if ($@) {
            xt_warn("An error occured whilst trying to confirm the Purchase Order: $@");
        }

    }
    return $handler->redirect_to( '/StockControl/PurchaseOrder/Confirm?po_id=' .$handler->{param_of}{po_id} );
}

1;

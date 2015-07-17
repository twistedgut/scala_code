package XTracker::Stock::Actions::SetPurchaseOrder;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database;
use XTracker::Database::PurchaseOrder       qw( :stock_order set_purchase_order_status check_purchase_order_status get_stock_orders );
use XTracker::Database::Product             qw( set_product_cancelled );
use XTracker::Utilities                     qw( :edit );
use XTracker::Error;
use XTracker::WebContent::StockManagement::Broadcast;
use List::AllUtils 'uniq';
use Try::Tiny;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    # unpack request parameters
    my ( $data_ref, $rest_ref ) = unpack_edit_params( $handler->{request} );
    my $po_id   = $rest_ref->{purchase_order_id};
    my $location=  "Overview?po_id=$po_id";

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;
    my $guard = $schema->txn_scope_guard;

    # get a list of all Stock Orders for this PO
    my $stock_order_list    = get_stock_orders( $dbh, { purchase_order_id => $po_id } );
    # convert to a hash with stock order id as the key
    my $stock_order_hash;
    foreach my $so ( @{ $stock_order_list } ) {
        $so->{cancel}   = ( defined $so->{cancel} ? $so->{cancel} : 0 );        # make sure 'cancel' is zero if it is NULL
        $stock_order_hash->{ $so->{id} }    = $so;
    }

    try { # update stock order items
        my $broadcast;my @pids;
        for my $item ( keys %{$data_ref} ) {
            my $cancel = $data_ref->{$item}->{cancel} eq 'on' ? 1 : 0;
            $broadcast ||= XTracker::WebContent::StockManagement::Broadcast->new({
                schema => $handler->schema,
                channel_id => $rest_ref->{'cid-'.$item},
            });

            # check to see if the current Cancel status of the Stock Order is
            # different to the request, if it is then change it else do nothing
            if ( $stock_order_hash->{ $item }{cancel} != $cancel ) {
                set_stock_order_details( $dbh,      { field => 'cancel', value => $cancel, so_id => $item } );
                set_stock_order_item_details( $dbh, { field => 'cancel', value => $cancel, id => $item, type => 'stock_order_id' } );
                set_product_cancelled( $dbh, { product_id => $rest_ref->{'pid-'.$item}, channel_id => $rest_ref->{'cid-'.$item}} )
                    if defined $rest_ref->{'pid-'.$item} and length $rest_ref->{'pid-'.$item};
            }
            push @pids,$rest_ref->{'pid-'.$item};
        }

        # set po status
        set_purchase_order_status( $dbh, {
            type   => 'purchase_order_id',
            id     => $po_id,
            status => check_purchase_order_status( $dbh, $po_id, 'purchase_order_id' ),
        });

        for my $pid (uniq @pids) {
            $broadcast->stock_update(
                quantity_change => 0,
                product_id => $pid,
                full_details => 1,
            );
        }

        $broadcast->commit() if $broadcast;

        $guard->commit();
    } catch {
        xt_warn( $_ );
    };

    return $handler->redirect_to( $location );
}

1;

package XTracker::Stock::Actions::CreateStockTransferRequest;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::StockTransfer;
use XTracker::Database::Product         qw( get_product_id );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $ret_params  = "?".$handler->{param_of}{orig_type}."=".$handler->{param_of}{orig_id};

    if ( $handler->{param_of}{"variant_id"} and $handler->{param_of}{"type_id"} ) {

        eval {
            my $schema = $handler->schema;
            my $dbh = $schema->storage->dbh;
            my $guard = $schema->txn_scope_guard;
            my $product_id = get_product_id($dbh,{ type => 'variant_id', id => $handler->{param_of}{variant_id} });

            my $prod_chann_id;
            my $product_row = $schema->resultset('Public::Product')->find($product_id);
            $prod_chann_id = $product_row->get_current_channel_id() if $product_row;

            my $stock_transfer_id   = create_stock_transfer( $dbh, $handler->{param_of}{type_id}, 1, $handler->{param_of}{variant_id}, $prod_chann_id, $handler->{param_of}{info} );

            $guard->commit();
            xt_success("Stock Requested");
        };
        if($@) {
            xt_warn($@)
        }
    }

    # redirect to Sample Summary
    my $loc = "/StockControl/Sample/RequestStock";

    return $handler->redirect_to( $loc.$ret_params );
}

1;

__END__

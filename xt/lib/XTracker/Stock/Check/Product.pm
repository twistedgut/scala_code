package XTracker::Stock::Check::Product;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Error qw( xt_warn );
use XTracker::Handler;
use XTracker::Navigation;
use XTracker::Database::Location qw( get_location_of_stock );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $product_id      = $handler->{param_of}{'product_id'};
    my $view            = $handler->{param_of}{'view'} // '';

    $handler->{data}{view}  = "HandHeld"                if (uc($view) eq "HANDHELD");

    $handler->{data}{scan}  = { action => '/StockControl/StockCheck/Product', field => 'product_id', name => 'PID/SKU', };

    if ( $handler->{data}{handheld} ) {
        $handler->{data}{content}       = 'check/handheld/product.tt';
        $handler->{data}{type}          = 'handheld';
        $handler->{data}{sidenav}       = {};
    }
    else {
        $handler->{data}{section}   = 'Stock Check';
        $handler->{data}{subsection}= 'Check Product';
        $handler->{data}{content}   = 'check/product.tt';
        $handler->{data}{sidenav}   = build_sidenav( { navtype => 'stock_check' } );
    }

    eval {
        my $variant_ref = ();

        # check if new format SKU entered
        if( defined $product_id and $product_id =~ m/-/ ) {
            $variant_ref = get_location_of_stock( $handler->{dbh}, { type => 'product', id => $product_id } );
        }
        # check if old format SKU entered
        elsif( defined $product_id and $product_id =~ m/_/ ) {
            $variant_ref = get_location_of_stock( $handler->{dbh}, { type => 'sku', id => $product_id } );
        }
        elsif ( defined $product_id ) {
            $variant_ref = get_location_of_stock( $handler->{dbh}, { type => 'product_id', id => $product_id } );
        }

        $handler->{data}{variants}      = $variant_ref;
    };

    if ($@) {
        xt_warn($@);
    }

    $handler->process_template( undef );

    return OK;
}

1;

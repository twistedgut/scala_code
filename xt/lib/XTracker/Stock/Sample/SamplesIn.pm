package XTracker::Stock::Sample::SamplesIn;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Product                 qw( get_product_id get_product_summary );
use XTracker::Database::PurchaseOrder   qw( set_stock_order_item_status get_sample_stock_order_id get_sample_stock_order_items );
use XTracker::Database::Stock                   qw( get_delivered_quantity );
use XTracker::Database::Utilities               qw( results_list );
use XTracker::Database::Profile                 qw( get_department );
use XTracker::Navigation                                qw( build_sidenav get_navtype );

sub handler {
        my $handler     = XTracker::Handler->new(shift);

    my ( $type, $id, $navargs, $navtype );

        if ( $id = $handler->{param_of}{'product_id'} ) {
                $navtype= 'product';
                $type   = 'product_id';
                $handler->{data}{product_id}    = $id;
        }
        elsif ( $id = $handler->{param_of}{'variant_id'} ) {
                $navtype= 'variant';
                $type   = 'variant_id';
                $handler->{data}{product_id}    = get_product_id( $handler->{dbh}, { type => 'variant_id', id => $id } );
        }

        if (defined $id) {
                $navargs->{type}        = $type;
                $navargs->{id}          = $id;
                $navargs->{navtype}     = get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->auth_level, type => $navtype, id => $handler->operator_id } );

                my $so_id                       = get_sample_stock_order_id( $handler->{dbh}, { type => $type, id => $id } );

                $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

                $handler->{data}{content}                       = 'stocktracker/sample/samplesin.tt';
                $handler->{data}{section}                       = "Stock Control";
                $handler->{data}{subsection}            = "Sample";
                $handler->{data}{subsubsection}         = "Goods In";
                $handler->{data}{stock_order_items}     = get_sample_stock_order_items( $handler->{dbh},  { type => 'stock_order_id', id => $so_id } );
                $handler->{data}{delivered}                     = get_delivered_quantity( $handler->{dbh}, { type => 'stock_order_id', id => $so_id, index => 'variant_id' } );
                $handler->{data}{stock_order_id}        = $so_id;
                $handler->{data}{type}                          = $type;
                $handler->{data}{id}                            = $id;
                $handler->{data}{sidenav}                       = build_sidenav( $navargs );
                $handler->{data}{department}            = get_department( { id => $handler->operator_id } );
        }
        else {
                $handler->{data}{error} = "Please select a product or a variant before clicking on Goods In";
        }

        $handler->process_template( undef );

    return OK;
}

1;

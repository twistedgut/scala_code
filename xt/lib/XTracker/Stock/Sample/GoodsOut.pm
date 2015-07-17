package XTracker::Stock::Sample::GoodsOut;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Barcode                           qw( create_barcode );
use XTracker::Navigation                        qw( build_sidenav get_navtype );
use XTracker::Database::Department      qw( &get_departments );
use XTracker::Database::Product         qw( get_variant_list get_product_id get_product_summary );
use XTracker::Database::Stock;
use XTracker::Database::Profile         qw( get_department );
use XTracker::Utilities                         qw( get_date_db );

sub handler {
        my $handler     = XTracker::Handler->new(shift);

        my ( %args, %args2, $navargs, $navtype, $product_id );


        if ( $handler->{param_of}{'variant_id'} || $handler->{param_of}{'product_id'} ) {

                if ( $handler->{param_of}{'variant_id'} ) {
                        %args  = ( type => 'variant_id', id => $handler->{param_of}{'variant_id'}, variant_type => 'Sample', type_id => 3, location => 'Sample Room' );
                        %args2 = ( type => 'variant_id', id => $handler->{param_of}{'variant_id'}, variant_type => 'Sample', type_id => 3, location => 'Transfer Pending' );
                        $navtype                        = 'variant';
                        $navargs->{type}        = 'variant_id';
                        $navargs->{id}          = $handler->{param_of}{'variant_id'};
                        $product_id                     = get_product_id( $handler->{dbh}, { type => 'variant_id', id => $handler->{param_of}{'variant_id'} } );
                }
                elsif ( $handler->{param_of}{'product_id'} ) {
                        %args  = ( type => 'product_id', id => $handler->{param_of}{'product_id'}, variant_type => 'Sample', type_id => 3, location => 'Sample Room' );
                        %args2 = ( type => 'product_id', id => $handler->{param_of}{'product_id'}, variant_type => 'Sample', type_id => 3, location => 'Transfer Pending' );
                        $navtype                        = 'product';
                        $navargs->{type}        = 'product_id';
                        $navargs->{id}          = $handler->{param_of}{'product_id'};
                        $product_id                     = $handler->{param_of}{'product_id'};
                }

                $navargs->{navtype}     = get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->auth_level, type => $navtype, id => $handler->operator_id } );

                $handler->{data}{product_id}    = $product_id;
                $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

                my $stock_to_rotate             = get_variant_list( $handler->{dbh}, \%args );
                my $stock_rotated               = get_variant_list( $handler->{dbh}, \%args2 );
                my $all_stock;

                $all_stock->{"torotate".$_} = $stock_to_rotate->{$_} for keys( %{ $stock_to_rotate } );
                $all_stock->{"rotated".$_} = $stock_rotated->{$_} for keys( %{ $stock_rotated } );

                $handler->{data}{content}                       = 'stocktracker/sample/goodsout.tt';
                $handler->{data}{section}                       = 'Stock Control';
                $handler->{data}{subsection}            = 'Vendor Sample';
                $handler->{data}{subsubsection}         = 'Goods Out to DC';
                $handler->{data}{sidenav}                       = build_sidenav( $navargs );
                $handler->{data}{auth_level}            = $handler->auth_level;
                $handler->{data}{variant}                       = $all_stock;

                $handler->{data}{department}    = get_department( { id => $handler->operator_id } );
        }
        else {
                $handler->{data}{error}         =  "product_id or variant_id not found";
        }

        $handler->process_template( undef );

        return OK;
}

1;

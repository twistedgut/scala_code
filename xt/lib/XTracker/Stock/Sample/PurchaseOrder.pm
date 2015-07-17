package XTracker::Stock::Sample::PurchaseOrder;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Navigation                    qw( build_sidenav get_navtype );
use XTracker::Database::Attributes;
use XTracker::Database::Product             qw( get_variant_list get_product_id get_product_summary );
use XTracker::Database::PurchaseOrder       qw( get_purchase_order get_purchase_order_type get_product get_status get_stock_orders );
use XTracker::Utilities                     qw( get_date_db );
use XTracker::Database::Profile             qw( get_department );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $type    = "";
    my $args;

    if ( $handler->{param_of}{product_id} || $handler->{param_of}{orig_product_id} ) {
        $type           = "product";
        $args->{type}   = 'product_id';
        $args->{id}     = $handler->{param_of}{orig_product_id} || $handler->{param_of}{product_id};
        $handler->{data}{orig_product_id}   = $args->{id};          # remember how the module was called for drawing the sidenav for later
    }
    if ( $handler->{param_of}{variant_id} || $handler->{param_of}{orig_variant_id} ) {
        $type           = "variant";
        $args->{type}   = 'variant_id';
        $args->{id}     = $handler->{param_of}{orig_variant_id} || $handler->{param_of}{variant_id};
        $handler->{data}{orig_variant_id}   = $args->{id};          # remember how the module was called for drawing the sidenav for later
    }

    $args->{navtype}    = get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->auth_level, type => $type, id => $handler->operator_id } );

    $handler->{data}{content}           = 'sample/purchase_order.tt';
    $handler->{data}{javascript}        = [ 'goodsin.tt' ];
    $handler->{data}{section}           = 'Stock Control';
    $handler->{data}{subsection}        = 'Sample';
    $handler->{data}{subsubsection}     = 'Purchase Order';
    $handler->{data}{designers}         = [ 'designer', get_designer_atts($handler->{dbh}) ];
    $handler->{data}{seasons}           = [ 'season',   get_season_atts($handler->{dbh}) ];
    $handler->{data}{sidenav}           = build_sidenav( $args );
    $handler->{data}{subsubsection}     = 'All Purchase Orders';
    $handler->{data}{defaultdate}       = get_date_db( { dbh => $handler->{dbh}, format_string => 'YYYY-MM-DD' } );

    my $ret;

    if ( $handler->{param_of}{po_id} ) {
        $ret    = _display_create_purchase_order_form( $handler, $handler->{param_of}{action} );
        return REDIRECT         if ($ret eq REDIRECT);
    }
    elsif ( $handler->{param_of}{variant_id} or $handler->{param_of}{product_id} ) {

        if ($handler->{param_of}{variant_id}) {
            $handler->{data}{product_id}    = get_product_id( $handler->{dbh}, { type => 'variant_id', id => $handler->{param_of}{variant_id} });
        }
        else {
            $handler->{data}{product_id}    = $handler->{param_of}{product_id}
        }
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );
        $handler->{data}{department}= get_department( { id => $handler->operator_id });

        $handler->{data}{action}    = 'displaypolist';
        $handler->{data}{list}      = get_purchase_order( $handler->{dbh}, $args->{id}, $args->{type} );
        foreach ( 0..$#{ $handler->{data}{list} } ) {
            $handler->{data}{list}[$_]{products}    = get_product( $handler->{dbh}, { type => 'purchase_order_id', id => $handler->{data}{list}[$_]{id} } );
        }
    }

    # TT dispatch
    $handler->process_template( undef );

    return OK;
}

### Subroutine : _display_create_purchase_order_form         ###
# usage        :                                               #
# description  :                                               #
# parameters   :                                               #
# returns      :                                               #

sub _display_create_purchase_order_form {

    my $handler     = shift;
    my $action      = shift;


    if ( $action && $action eq 'create' ) {
        $handler->{data}{action}    = 'displaycreateform';
        $handler->{data}{clause}    = 'Main';
    }
    else {
        my $loc = "/StockControl/PurchaseOrder/Overview?po_id=$handler->{param_of}{'po_id'}";
        return $handler->redirect_to( $loc );
    }

    $handler->{data}{list}                  = get_purchase_order( $handler->{dbh}, $handler->{param_of}{"po_id"}, 'purchase_order_id' );
    $handler->{data}{sales_channel}         = $handler->{data}{list}[0]{sales_channel};
    $handler->{data}{purchase_order_type}   = get_purchase_order_type( $handler->{dbh} );
    $handler->{data}{purchase_order_status} = get_status( $handler->{dbh} );

    if ( $action eq 'create' ) {
        $handler->{data}{products}  = get_product( $handler->{dbh}, { type => 'purchase_order_id', id => $handler->{data}{list}[0]{id},
                                                 clause => 'stock_order_type', value => $handler->{data}{clause}, results => 'array' } );

        foreach my $product ( @{$handler->{data}{products}} ) {
            foreach my $p ( $product->{$product} ) {
                $product->{variants} = get_variant_list( $handler->{dbh}, { type => 'product_id', id => $product->{product_id} } );
            }
        }
    }
    else {
        $handler->{data}{products}  = get_stock_orders( $handler->{dbh}, { purchase_order_id => $handler->{data}{list}[0]{id} } );

        foreach my $product ( @{$handler->{data}{products}} ) {
            foreach my $p ( $product->{$product} ) {
                $product->{variants} = get_variant_list( $handler->{dbh}, { type => 'product_id', id => $product->{product_id},
                                                                 restriction_type => 'soi.type_id', restriction_value => '3' } );
            }
        }
    }
}

1;

__END__

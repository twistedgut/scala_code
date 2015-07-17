package XTracker::Stock::Inventory::StockQuarantine;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Navigation qw( get_navtype build_sidenav );
use XTracker::Database::Product qw( get_product_id get_product_summary get_variant_list );
use XTracker::Database::Stock qw( get_located_stock );

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new( $r );

    # query string vars
    $handler->{data}{product_id}    = $handler->{request}->param('product_id') || 0;
    $handler->{data}{variant_id}    = $handler->{request}->param('variant_id') || 0;
    $handler->{data}{view_channel}  = $handler->{request}->param('view_channel') || '';

    # arguments to build side nav and get variant data
    my %args = ();

    if( $handler->{data}{variant_id} ){
        $handler->{data}{product_id}    = get_product_id( $handler->{dbh}, { type => 'variant_id', id => $handler->{data}{variant_id} } );
        %args                           = ( type => 'variant_id', id => $handler->{data}{variant_id}, exclude_iws => 1, exclude_prl => 1 );
        $args{navtype}                  = get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->{data}{auth_level}, type => 'variant', id => $handler->{data}{operator_id} } );
    }
    elsif( $handler->{data}{product_id} ){
        %args           = ( type => 'product_id', id => $handler->{data}{product_id}, exclude_iws => 1, exclude_prl => 1 );
        $args{navtype}  = get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->{data}{auth_level}, type => 'product', id => $handler->{data}{operator_id} } );
    }
    else{
        # can't do anything without a variant or product id
    }

    $args{operator_id}          = $handler->operator_id;
    $handler->{data}{sidenav}   = build_sidenav( \%args );

    $handler->{data}{content}       = 'inventory/stock_quarantine.tt';
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = 'Quarantine Stock';

    # YUI stuff needed for channel tabs
    $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];


    $args{iws_rollout_phase} = $handler->iws_rollout_phase;

    if ( $args{type} ) {

        # get common product summary data for header
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

        # get variant and location info
        $handler->{data}{variant}           = get_variant_list(  $handler->{dbh}, \%args, { by => 'stock_main' } );
        $handler->{data}{variant_transit}   = get_variant_list(  $handler->{dbh}, \%args, { by => 'stock_transit' } );
        $handler->{data}{located}           = get_located_stock( $handler->{dbh}, \%args, 'stock_main' );
        $handler->{data}{transit}           = get_located_stock( $handler->{dbh}, \%args, 'stock_transit' );
    }

    $handler->process_template( undef );

    return OK;
}

1;

__END__

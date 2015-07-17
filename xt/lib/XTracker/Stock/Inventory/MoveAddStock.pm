package XTracker::Stock::Inventory::MoveAddStock;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Navigation qw( get_navtype build_sidenav );

use XTracker::Database::Product qw( get_product_id get_product_summary get_variant_list get_variant_by_sku );
use XTracker::Database::Stock;
use XTracker::Database::Channel qw( get_channels );
use XTracker::Error;
use XTracker::Constants::Regex ':sku';
use XTracker::Constants::FromDB qw(:flow_status);
use XTracker::Config::Local qw( iws_location_name );

sub handler {
    my $handler = XTracker::Handler->new( shift );

    # query string vars
    $handler->{data}{view}          = $handler->{request}->param('view');
    $handler->{data}{product_id}    = $handler->{request}->param('product_id') || 0;
    $handler->{data}{sku}           = $handler->{request}->param('sku') || 0;
    $handler->{data}{variant_id}    = $handler->{request}->param('variant_id') || 0;
    $handler->{data}{view_channel}  = $handler->{request}->param('view_channel') || '';

    $handler->{data}{content}       = 'inventory/move_add_stock.tt';
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = 'Move/Add Stock';
    $handler->{data}{iws_location_name} = iws_location_name();

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
    elsif( $handler->{data}{sku} ){
        if ( $handler->{request}->param('sku') =~ $SKU_REGEX ) {
            $handler->{data}{variant_id}    = get_variant_by_sku($handler->{dbh}, $handler->{request}->param('sku'));
            if ( defined $handler->{data}{variant_id} ) {
                $handler->{data}{product_id}    = get_product_id( $handler->{dbh}, { type => 'variant_id', id => $handler->{data}{variant_id} } );
                %args                           = ( type => 'variant_id', id => $handler->{data}{variant_id}, exclude_iws => 1, exclude_prl => 1 );
                $args{navtype}                  = get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->{data}{auth_level}, type => 'variant', id => $handler->{data}{operator_id} } );
            }
            else {
                xt_warn( "SKU not found" );
            }
        }
        else {
            xt_warn( "Invalid SKU entered" );
        }
    }
    else{
        # can't build the side nav without a variant or product id
    }

    if (grep { not ($_ && m{^handheld$}i) } $handler->{data}{view}) {
        $args{operator_id}  = $handler->operator_id;
        $handler->{data}{sidenav} = build_sidenav( \%args );
    }

    if ( $args{type} ) {

        # get common product summary data for header
        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

        # get variant and location info
        $handler->{data}{channels}          = get_channels( $handler->{dbh} );
        $handler->{data}{variant}           = get_variant_list( $handler->{dbh}, \%args, { by => 'size_list' } );
        $handler->{data}{located}           = get_located_stock( $handler->{dbh}, \%args );
        $handler->{data}{main_status_id}    = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
    }

    return $handler->process_template;
}

1;

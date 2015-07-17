package XTracker::Stock::Inventory::ProductDetails;

use strict;
use warnings;
use XTracker::Handler;
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Navigation qw( get_navtype build_sidenav );
use XTracker::Database::Attributes qw( get_countries );
use XTracker::Database::Product qw( get_product_summary get_product_shipping_attributes );
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw( :storage_type );
use XTracker::Error qw( xt_warn );
use Try::Tiny;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $schema = $handler->schema;
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = 'Product Details';
    $handler->{data}{content}       = 'stocktracker/inventory/product_details.tt';

    # get product or variant id from url
    $handler->{data}{product_id}    = $handler->{request}->param('product_id');
    $handler->{data}{variant_id}    = $handler->{request}->param('variant_id');

    # build correct side nav
    my %args = ();

    if( $handler->{data}{product_id} ){
        %args = ( type => 'product_id', id => $handler->{data}{product_id}, nav_type => 'product' );
    }
    elsif( $handler->{data}{variant_id} ){
        %args = ( type => 'variant_id', id => $handler->{data}{variant_id}, nav_type => 'variant' );
        $handler->{data}{product_id} = get_product_id( $handler->dbh, { type => 'variant_id', id => $handler->{data}{variant_id} } );
    }

    $args{navtype}  = get_navtype({
        dbh        => $handler->dbh,
        auth_level => $handler->{data}{auth_level},
        type       => $args{nav_type},
        id         => $handler->{data}{operator_id},
    });

    $handler->{data}{sidenav} = build_sidenav( \%args );

    # get common product summary data for header
    $handler->add_to_data( get_product_summary( $schema, $handler->{data}{product_id} ) );

    my $product = $handler->{data}{product_row}
        = $schema->resultset('Public::Product')->find($handler->{data}{product_id})
       || $schema->resultset('Voucher::Product')->find($handler->{data}{product_id});

    # Vouchers have no shipping restrictions, and they don't have a storage
    # type log
    unless ( $handler->{data}{product}{voucher} ) {
        my $ship_restrictions = $product->get_shipping_restrictions_status;
        $handler->{data}{is_hazmat}    = $ship_restrictions->{is_hazmat};
        $handler->{data}{is_aerosol}   = $ship_restrictions->{is_aerosol};
        $handler->{data}{is_hazmat_lq} = $ship_restrictions->{is_hazmat_lq};

        # get storage type logs for this product
        $handler->add_to_data({
            audit_log_data => {
                storage_type => {
                    title    => 'Storage Type',
                    rows     => [
                        $product->audit_recents->search(
                            { col_name => 'storage_type_id' },
                            { order_by => { -desc => 'timestamp' } }
                        )->all
                    ],
                },
                map { $_ => {
                    title => ucfirst $_,
                    rows  => [
                        $product->shipping_attribute->audit_recents->search(
                            { col_name => $_ },
                            { order_by => { -desc => 'timestamp' } }
                        )->all
                    ],
                } } qw{length width height weight},
            },
        });
    }

    # list of countries for country of origin select
    $handler->{data}{countries}     = [ 'country', get_countries( $handler->dbh ) ];
    $handler->{data}{storage_types} = $schema->resultset('Product::StorageType')->get_options;

    # local settings from config
    $handler->{data}{weight_unit}     = config_var('Units', 'weight');
    $handler->{data}{dimensions_unit} = config_var('Units', 'dimensions');
    $handler->{data}{dc_name}         = config_var('DistributionCentre', 'name');

    return $handler->process_template;
}

1;

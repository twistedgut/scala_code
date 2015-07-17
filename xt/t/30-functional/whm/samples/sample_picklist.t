#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

sample_picklist.t - Test the printing of sample picklists

=head1 DESCRIPTION

Request a sample and approve it, then test the printing of sample picklists
(only happens when picking is done manually in XT, so doesn't run if we have
IWS or PRLs).

#TAGS printer sample inventory fulfilment selection phase0 picklist whm

=head1 SEE ALSO

sample_printing.t

=cut

use FindBin::libs;

use Test::XTracker::RunCondition iws_phase => 0, prl_phase => 0;


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Flow;
use Test::More::Prefix qw( test_prefix );

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw( :authorisation_level :storage_type :flow_status );
use Data::Dump  qw( pp );

my $perms = {
    $AUTHORISATION_LEVEL__OPERATOR => [
        'Goods In/Bag And Tag',
        'Goods In/Item Count',
        'Goods In/Putaway',
        'Goods In/Quality Control',
        'Goods In/Stock In',
        'Goods In/Surplus',
        'RTV/Faulty GI',
    ],
    $AUTHORISATION_LEVEL__MANAGER => [
        'Stock Control/Location',
        'Stock Control/Sample',
        'Stock Control/Cancellations',
        'Stock Control/Dead Stock',
        'Stock Control/Final Pick',
        'Stock Control/Inventory',
        'Stock Control/Measurement',
        'Stock Control/Quarantine',
        'Stock Control/Stock Adjustment',
        'Stock Control/Stock Check',
        'Stock Control/Stock Relocation',
        'RTV/Inspect Pick',
        'RTV/Pick RTV',
        'RTV/Pack RTV',
        'Fulfilment/Selection',
    ],
};

my $schema      = Test::XTracker::Data->get_schema;
my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::StockControl',
        'Test::XT::Flow::Fulfilment',
    ],
);

#
# Test the ProductDetails page
#   - specifically setting the storage_type and the resultant AMQ message to IWS
#

# Get 1 product
my ($channel,$pids) = Test::XTracker::Data->grab_products( {
                                how_many => 1,
                                channel => 'nap',
                            } );

# make sure one product has stock
#Test::XTracker::Data->ensure_stock($pids->[0]->{'pid'}, $pids->[0]->{'size_id'}, $channel->id );

# store products in handly list
my $product = $schema->resultset('Public::Product')->find($pids->[0]->{pid});
my $product_variants = $product->variants();
my $product_variant = undef;
while ( my $pv = $product_variants->next() ) {
    $product_variant = $pv->id();
    last;
}

my $prod_loc    = Test::XTracker::Data->set_product_stock({
    variant_id  => $product_variant,
    channel_id  => $channel->id(),
    quantity    => 100,
    stock_status => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
} );

# check data set up OK
ok( $product->has_stock, 'product has stock' );

# ensure storage types set on products
$product->update({storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT});

# righto - go to the ProductDetails page for each product
#
$framework->login_with_permissions( { perms => $perms } );

$framework->flow_mech__stockcontrol__inventory()
    ->flow_mech__stockcontrol__inventory_submit( $product->id() )
    ->flow_mech__stockcontrol__sample_request_stock__by_variant( $product_variant )
    ->flow_mech__stockcontrol__sample_request_stock_submit();

test_prefix('Approve request');

# latest request, should be ours
my $transfer = $schema->resultset('Public::StockTransfer')->search( {
    variant_id => $product_variant,
},{
    order_by => { -desc => 'date' },
})->slice(0,0)->single;

$framework->flow_mech__stockcontrol__sample_requests()
    ->flow_mech__stockcontrol__sample_requests_submit( $transfer->id );

test_prefix('Fulfilling request');
my $shipments = $transfer->link_stock_transfer__shipments();
my $shipment_nr = undef;
while( my $shipment = $shipments->next() ) {
    $shipment_nr = $shipment->shipment_id();
    last;
}

my $print_directory = Test::XTracker::PrintDocs->new(strict_mode => 0);

$framework->flow_mech__fulfilment__selection_transfer()
    ->flow_mech__fulfilment__selection_submit( $shipment_nr );

my @print_dir_new_file = $print_directory->wait_for_new_files( files => 1 );
is( scalar( @print_dir_new_file ), 1, 'Correct number of files printed' );

is( $print_dir_new_file[0]->{file_type}, 'pickinglist', 'Correct file type' );

#Uncomment this when the lp_noprint will be fixed or put a sleep( 2 )
#
#is( $print_dir_new_file[0]->{printer_name}, '', 'Sent to the correct printer' );
#is( $print_dir_new_file[0]->{copies}, 1, 'Correct number of copies printed' );

done_testing();

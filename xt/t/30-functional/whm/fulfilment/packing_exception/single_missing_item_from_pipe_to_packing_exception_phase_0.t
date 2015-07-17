#!/usr/bin/env perl

=head1 NAME

single_missing_item_from_pipe_to_packing_exception_phase_0.t - Cancel an item on PIPE page (no IWS or PRL)

=head1 DESCRIPTION

Test based on missing_items_from_pipe_to_packing_exception.t

With this test we're repeating the same testing logic as on the above but with
an item which we are forcing to only have one unit of stock.

=head2 Shipment changes during PIPE

Load up a shipment with 5 items. Pick, and place it on hold. Start to pack,
which takes us to PIPE page. While on the PIPE page, cancel an item.

#TAGS fulfilment packing packingexception phase0 whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition iws_phase => 0, prl_phase => 0;


use Test::XTracker::Data qw/qc_fail_string/;
use Test::XT::Flow;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Constants::FromDB qw/ :flow_status /;

# Start-up gubbins here. Test plan follows later in the code...
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::AppMessages',
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
);

$framework->clear_sticky_pages;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

# set up an amq read dir
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
my $schema = Test::XTracker::Data->get_schema;

# Russle up 1 products
my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many_variants => 1,
    force_create      => 1,
});

# create a picked order with those pids
my $product_data =
    $framework->flow_db__fulfilment__create_order( channel => $channel, products => $pids );
my $shipment_id = $product_data->{'shipment_id'};
my ($tote_id)   = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );
my $order_id    = $product_data->{order_object}->id;
my $channel_id  = $product_data->{channel_object}->id;

note "Ensure a packing station is set";
$framework->mech__fulfilment__set_packing_station( $channel_id );

# Force stock to 1 unit
Test::XTracker::Data->set_product_stock({
    variant_id     => $pids->[0]->{variant_id},
    quantity       => 1,
    channel_id     => $channel->id,
    stock_status   => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    exact_quantity => 1,
});

# Make sure we really only have a unit of valid stock for this item
my $variant_quantity_rs = $schema->resultset('Public::Quantity')->search({
    variant_id => $pids->[0]->{variant_id},
    status_id  => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
    channel_id => $channel->id,
});

is(
    $variant_quantity_rs->get_column('quantity')->sum,
    1,
    "Assert only one available item for SKU",
);

# Select and pick the order

my ($shipment, $container_id) = $framework->task__selection($product_data->{shipment_object});
($shipment, $container_id) = $framework->task__picking($product_data->{shipment_object});

# set some vars
my %products = map {; "P$_" => shift( @$pids ) } 1..(scalar @$pids);

# Pack the items
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $shipment_id );

# Fail items
my @items_to_fail = @{$framework->mech->as_data()->{shipment_items}};

my $fail_reason = 'Missing' . rand(100000000);

# Let's QC fail a couple of items whilst packing and provide a reason
$framework->errors_are_fatal(0);
$framework
    ->flow_mech__fulfilment__packing_checkshipment_submit(
        fail => {
            $items_to_fail[0]->{'shipment_item_id'} => $fail_reason,
        }
    );
$framework->errors_are_fatal(1);


# Finish packing it on the PIPE page
my ($faulty_container) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );

$framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $products{"P1"}->{'sku'} )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $faulty_container )
    ->flow_mech__fulfilment__packing_placeinpetote_mark_complete();

# at this point we expect 3 messages :
#   a shipment_request
#   a shipment received
#   a shipment reject
$xt_to_wms->expect_messages({
    messages => [
        { '@type' => 'shipment_request'  },
        { '@type' => 'shipment_received' },
        { '@type' => 'shipment_reject'   },
    ]
});

# Let's now go and check the PackingException test,
# let's confirm that item is missing

is($variant_quantity_rs->get_column('quantity')->sum,0,"Assert 0 items available for SKU");

$framework
    ->clear_sticky_pages
    ->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $shipment_id )
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_missing(
        $items_to_fail[0]->{'shipment_item_id'},
    );

my $missing_sku = $items_to_fail[0]->{'SKU'};
$framework
    ->catch_error(
        qr{The following item does not have a replacement available in stock: $missing_sku},
        'Supervisor shown message about no replacement available',
        flow_mech__fulfilment__packing_checkshipmentexception_submit => () );

is($variant_quantity_rs->get_column('quantity')->sum,0,"I'm assuming this should now be 0 no ? If the SKU was marked as lost ???");

# Check that the missing items are in NEW state
my $items_ready_to_be_picked_count = $schema->resultset('Public::ShipmentItem')
    ->search({
        shipment_id             => $shipment_id,
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
    })->count;

is($items_ready_to_be_picked_count,1,"Right number of items in (NEW/SELECTED) state");

$xt_to_wms->expect_messages({
    messages => [
        {
            '@type'   => 'item_moved',
            'details' => { 'items' => [{ sku => $items_to_fail[0]->{'SKU'}}] }
        },
        {   '@type'   => 'shipment_wms_pause', }
    ]
});

done_testing();

#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

stock_control_phase0.t - Test the Public::Channel methods when IWS is off

=head1 DESCRIPTION

Create a purchase order with a delivery.

Hack in some log data and check that the product's allocated, delivery, rtv and
pws logs have tabs.

Perform stock in and item count with ten more items than was on the packing slip.

Go to the Stock Control/Inventory and submit the product.

Go to the variant overview page and click on product details - check it's channelised.

Go to the pricing page, check it's channelised.

Go to the sizing page, check it's channelised.

Go to Stock Control/Location page and create a new location for NAP. Repeat.

Do this again for two Outnet locations.

Search for one of the created NAP locations and check the result is channelised.

Go to Stock Control/Measurement, submit the product and check the result is a
channelised page (i.e. we have a result).

Insert a quantity one of the NAP location.

Go to Stock Control/Stock Check and submit the NAP location, check the result
is a channelised page.

Go to Stock Control/Stock Relocation, move stock from one of the created
locations to the other, and move it back.

Return to the Stock Control/Stock Relocation page.

Try and relocate some stock from a NAP channel to an Outnet one - don't die on
an error NOTE THAT THIS DOESN'T ACTUALLY CHECK THAT AN ERROR IS PRINTED!

Go to the Stock Control/Stock Adjustment page and submit, verify that it's
channelised and try and submit a change, check we have a confirmation message
and no error message.

Go to the variant transaction log and check that it's channelised (i.e. it has
content). Go to the location log and check that it's channelised (i.e. it has
content).

There's are then a few stub dead stock calls that are made (i.e. they do
*nothing*).

Set the quantity to 0 in all locations for the variant, then go to Stock
Control/Final Pick. Check that the page title is 'Empty Locations' and that the tab is channelised.

#TAGS createlocation stockcheck stockrelocation stockadjustment phase0 relocate quarantine inventory purchaseorder goodsin itemcount finalpick locationlog transactionlog allocatedlog deliverylog rtvlog pwslog sizing pricing rtv iws pws picking packing fulfilment toobig wip needswork whm

=head1 TODO

Implement quarantine

=head1 SEE ALSO

stock_control.t

=cut

use FindBin::libs;


use Test::XT::Flow;

use Test::XTracker::RunCondition iws_phase => '0', export => qw( $iws_rollout_phase );

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :stock_order_status
    :delivery_status
    :std_size
    );
use Test::XTracker::Mechanize::StockControl;

my $flow1 = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::PurchaseOrder',
        'Test::XT::Flow::StockControl',
        'Test::XT::Data::Location',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::PrintStation',
        'Test::XT::Feature::Ch11n',
        'Test::XT::Feature::Ch11n::StockControl',
    ],
);

my $flow2 = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::PurchaseOrder',
        'Test::XT::Data::StockLog',
        'Test::XT::Data::Location',
        'Test::XT::Data::Customer',
        'Test::XT::Data::Reservation',
        'Test::XT::Data::Order',
        'Test::XT::Data::Delivery',
        'Test::XT::Data::Shipment',
        'Test::XT::Data::RTV',
        'Test::XT::Flow::StockControl',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Feature::Ch11n',
        'Test::XT::Feature::Ch11n::StockControl',
    ],
);

plan skip_all => 'This test requires the channels NAP, OUTNET & MRP to be enabled.'
    unless $flow1
        ->schema
        ->resultset('Public::Channel')
        ->channels_enabled( qw( NAP OUTNET MRP ) );

note 'Clear all test locations';
$flow1->data__location__destroy_test_locations;

my $size_ids = Test::XTracker::Data->find_valid_size_ids(2);

# Over-ride the default purchase order and create one with a delivery.
my $purchase_order = Test::XTracker::Data->create_from_hash({
    channel_id      => $flow2->mech->channel->id,
    placed_by       => 'Ian Docherty',
    confirmed       => 1,
    stock_order     => [{
        status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
        product         => {
            product_type_id => 6,
            style_number    => 'ICD STYLE',
            variant         => [{
                size_id         => $size_ids->[0],
                stock_order_item    => {
                    quantity            => 40,
                },
            },{
                size_id         => $size_ids->[1],
                stock_order_item    => {
                    quantity            => 33,
                },
            }],
            product_channel => [{
                channel_id      => $flow2->mech->channel->id,
            }],
            product_attribute => {
                description     => 'New Description',
            },
            price_purchase => {},
            delivery => {
                status_id   => $DELIVERY_STATUS__COUNTED,
            },
        },
    }],
});
$flow2->purchase_order($purchase_order);


my $perms = {
    $AUTHORISATION_LEVEL__OPERATOR => [
        'Goods In/Bag And Tag',
        'Goods In/Item Count',
        'Goods In/Putaway',
        'Goods In/Quality Control',
        'Goods In/Stock In',
        'Goods In/Surplus',
        'RTV/Faulty GI',
        'Stock Control/Cancellations',
        'Stock Control/Dead Stock',
        'Stock Control/Final Pick',
        'Stock Control/Inventory',
        'Stock Control/Measurement',
        'Stock Control/Quarantine',
        'Stock Control/Stock Adjustment',
        'Stock Control/Stock Check',
        'Stock Control/Stock Relocation',
    ],
    $AUTHORISATION_LEVEL__MANAGER => [
        'Stock Control/Location',
        'RTV/Inspect Pick',
        'RTV/Pick RTV',
        'RTV/Pack RTV',
    ],
};

my $loc_opts = {
    channel_id      => $flow1->mech->channel->id,
};

my $outnet_loc_opts = {
    channel_id      => $flow1->alternate_channel->id,
};

my $location_names = $flow1->data__location__get_unused_location_names(2);

note "1 locations : ". join(',',@{$location_names});
note "1 product   : ". $flow1->product->id;

my $outnet_location_names = $flow1->data__location__get_unused_location_names(2);

note "outnet locations : ". join(',',@{$outnet_location_names});

# Request the rtv_quantity_id and reservation to ensure they are built (lazily)
my $rtv_quantity_id = $flow2->rtv_quantity_id;
my $reservation     = $flow2->reservation;
my $order           = $flow2->order;

note "2 product   : ". $flow2->product->id;
note "delivery    : ". $flow2->delivery->id;
note "shipment    : ". $flow2->shipment->id;

my @flow_1_variants = map { $_->variant }
    $flow1->purchase_order->stock_orders->first->stock_order_items;

$flow2->login_with_permissions({
    dept => 'Distribution Management',
    perms => $perms,
    })
    # Put data into the logs
    ->set_log_delivery
    ->set_log_rtv_stock
    ->set_log_pws_stock
    # Now there should be something in the logs to check against
    ->flow_mech__stockcontrol__inventory_log_product_allocatedlog
        ->test_mech__stockcontrol__inventory_log_product_allocatedlog_ch11n
    ->flow_mech__stockcontrol__inventory_log_product_deliverylog
        ->test_mech__stockcontrol__inventory_log_product_deliverylog_ch11n
    ->flow_mech__stockcontrol__inventory_log_variant_rtvlog
        ->test_mech__stockcontrol__inventory_log_variant_rtvlog_ch11n
    ->flow_mech__stockcontrol__inventory_log_variant_pwslog
        ->test_mech__stockcontrol__inventory_log_variant_pwslog_ch11n
    ;

$flow1->purchase_order->update({ confirmed => 1 });

$flow1->login_with_permissions({
    dept => 'Distribution Management',
    perms => $perms,
    });
$flow1->flow_mech__select_printer_station( {
 section => 'GoodsIn',
 subsection => 'StockIn',
 } );

$flow1->flow_mech__select_printer_station_submit;
$flow1
    ->flow_mech__goodsin__stockin_packingslip( $flow1->stock_order->id )
    ->flow_mech__goodsin__stockin_packingslip__submit({
        $flow_1_variants[0]->sku => 40,
        $flow_1_variants[1]->sku => 33,
    });

$flow1->flow_mech__select_printer_station(
    { section => 'GoodsIn', subsection => 'ItemCount', }
);
$flow1->flow_mech__select_printer_station_submit;

$flow1
    ->flow_mech__goodsin__itemcount()
    ->flow_mech__goodsin__itemcount_scan(
        $flow1->purchase_order->stock_orders->first->deliveries->first->id
    )->flow_mech__goodsin__itemcount_submit_counts({
        counts => {
            $flow_1_variants[0]->sku => 50, # Ten more than was on the packing slip
            $flow_1_variants[1]->sku => 33,
        },
        weight => '1.5',
    })
    ->inline_force_datalite(0)

    ->flow_mech__stockcontrol__inventory
        ->flow_mech__stockcontrol__inventory_submit
    ->flow_mech__stockcontrol__inventory_overview_variant
    ->flow_mech__stockcontrol__inventory_productdetails
        ->test_mech__stockcontrol__inventory_productdetails_ch11n
    ->flow_mech__stockcontrol__inventory_pricing
        ->test_mech__stockcontrol__inventory_pricing_ch11n
    ->flow_mech__stockcontrol__inventory_sizing
        ->test_mech__stockcontrol__inventory_sizing_ch11n
    ->flow_mech__stockcontrol__location_create
        ->flow_mech__stockcontrol__location_create_submit($loc_opts,$location_names->[0])
    ->flow_mech__stockcontrol__location_create
        ->flow_mech__stockcontrol__location_create_submit($loc_opts,$location_names->[1])
    ->flow_mech__stockcontrol__location_create
        ->flow_mech__stockcontrol__location_create_submit($outnet_loc_opts,$outnet_location_names->[0])
    ->flow_mech__stockcontrol__location_create
        ->flow_mech__stockcontrol__location_create_submit($outnet_loc_opts,$outnet_location_names->[1])
    ->flow_mech__stockcontrol__location
        ->test_mech__stockcontrol__location_ch11n
        ->flow_mech__stockcontrol__location_submit($location_names->[0])
    ->flow_mech__stockcontrol__measurement
        ->flow_mech__stockcontrol__measurement_submit
        ->test_mech__stockcontrol__measurement_submit_ch11n
    ->data__insert_quantity($location_names->[0])
    ->flow_mech__stockcontrol__stockcheck
        ->flow_mech__stockcontrol__stockcheck_submit($location_names->[0])
        ->test_mech__stockcontrol__stockcheck_submit_ch11n
    ->flow_mech__stockcontrol__stockcheck_product
        ->flow_mech__stockcontrol__stockcheck_product_submit
        ->test_mech__stockcontrol__stockcheck_product_submit_ch11n
    ->flow_mech__stockcontrol__stockrelocation
        ->flow_mech__stockcontrol__stockrelocation_submit($location_names->[0],$location_names->[1])
    ->flow_mech__stockcontrol__stockrelocation
        ->flow_mech__stockcontrol__stockrelocation_submit($location_names->[1],$location_names->[0])
    ->flow_mech__stockcontrol__stockrelocation;
    $flow1->errors_are_fatal(0); # this next method should fail as location channels don't match
    $flow1->flow_mech__stockcontrol__stockrelocation_submit($location_names->[0],$outnet_location_names->[1]);
    $flow1->errors_are_fatal(1);
    $flow1->flow_mech__stockcontrol__inventory_stockadjustment_variant
        ->test_mech__stockcontrol__inventory_stockadjustment_variant_ch11n
        ->flow_mech__stockcontrol__inventory_stockadjustment_variant_submit
    ->flow_mech__stockcontrol__inventory_log_variant_transactionlog
        ->test_mech__stockcontrol__inventory_log_variant_transactionlog_ch11n
    ->flow_mech__stockcontrol__inventory_log_variant_locationlog
        ->test_mech__stockcontrol__inventory_log_variant_locationlog_ch11n

    # dead stock
    ->flow_mech__stockcontrol__dead_stock_add_item
        ->test_mech__stockcontrol__dead_stock_add_item
    ->flow_mech__stockcontrol__dead_stock_view_list
        ->test_mech__stockcontrol__dead_stock_view_list
    ->flow_mech__stockcontrol__dead_stock_update
        ->test_mech__stockcontrol__dead_stock_update

#     ->flow_mech__stockcontrol__inventory_stockquarantine
#        ->test_mech__stockcontrol__inventory_stockquarantine
# haven't implemented this bit cos pete's done it in a weird way and I've got
# more pressing stuff to do
#        ->flow_mech__stockcontrol__inventory_stockquarantine_submit

    ->data__location__set_zero_quantity
    ->flow_mech__stockcontrol__finalpick
        ->test_mech__stockcontrol__final_pick_ch11n

#    ->data__set_non_zero_quantity
    ;
note 'Clear all test locations';
$flow1->data__location__destroy_test_locations;

done_testing;
1;

# WIP

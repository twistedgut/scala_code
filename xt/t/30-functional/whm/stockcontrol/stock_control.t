#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

stock_control_phase0.t - Test the Public::Channel methods when IWS is on

=head1 DESCRIPTION

Create a purchase order with a delivery.

Perform Item Count with ten more items than was on the packing slip.

Click through *a lot* of other pages, create locations, submit measurements,
check logs.

Note that this test is a candidate for deletion as it is very broad-ranging and
pretty much checks that we can just hit pages, and that there's a tab. The
former should be covered by other tests, the latter could be useful one day,
but this test would require a rewrite and a rename (and loop across channels
other than NAP) if we want it to act as such.

#TAGS inventory purchaseorder goodsin itemcount rtv iws pws picking packing fulfilment toobig checkruncondition shoulddelete whm

=head1 SEE ALSO

stock_control_phase0.t

=cut

use FindBin::libs;
use Test::XT::Flow;

use Test::XTracker::RunCondition dc => 'DC1', iws_phase => 'iws', export => qw( $iws_rollout_phase );

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
        'Test::XT::Feature::Measurements'
    ],
);

my $flow2 = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::PurchaseOrder',
        'Test::XT::Data::StockLog',
        'Test::XT::Data::Location',
        'Test::XT::Data::Customer',
        'Test::XT::Flow::PrintStation',
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
        'Stock Control/Inventory',
        'Stock Control/Measurement',
        'Stock Control/Stock Check',
        'Stock Control/Stock Relocation',
        'Stock Control/Quarantine',
        'Stock Control/Dead Stock',
        'Stock Control/Cancellations',
        'Stock Control/Product Approval',
        'Stock Control/Final Pick',
        'Goods In/Stock In',
        'Goods In/Item Count',
        'Goods In/Surplus',
        'Goods In/Quality Control',
        'Goods In/Bag And Tag',
        'Goods In/Putaway',
        'RTV/Faulty GI',
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

note "nap locations : ". join(',',@{$location_names});
note "nap product   : ". $flow1->product->id;

my $outnet_location_names = $flow1->data__location__get_unused_location_names(2);

note "outnet locations : ". join(',',@{$outnet_location_names});

$flow1->data__create_locations(
    [@$location_names,@$outnet_location_names],
    $flow1->all_location_types
);

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

$flow1->flow_mech__goodsin__itemcount()
    ->flow_mech__goodsin__itemcount_scan(
        $flow1->purchase_order->stock_orders->first->deliveries->first->id
    )->flow_mech__goodsin__itemcount_submit_counts({
        counts => {
            $flow_1_variants[0]->sku => 50, # Ten more than was on the packing slip
            $flow_1_variants[1]->sku => 33,
        },
        weight  => '1.5',
    })
    ->data__insert_quantity($location_names->[0])
    ->inline_force_datalite(0)

    ->flow_mech__stockcontrol__inventory
        ->flow_mech__stockcontrol__inventory_submit
    ->flow_mech__stockcontrol__product_overview__measurement_link
        ->test_mech__stockcontrol__product_overview__measurement_link
    ->flow_mech__stockcontrol__inventory_overview_variant
    ->flow_mech__stockcontrol__inventory_productdetails
        ->test_mech__stockcontrol__inventory_productdetails_ch11n
    ->flow_mech__stockcontrol__inventory_pricing
        ->test_mech__stockcontrol__inventory_pricing_ch11n
    ->flow_mech__stockcontrol__inventory_sizing
        ->test_mech__stockcontrol__inventory_sizing_ch11n
    ->flow_mech__stockcontrol__location
        ->test_mech__stockcontrol__location_ch11n
        ->flow_mech__stockcontrol__location_submit($location_names->[0])
    ->flow_mech__stockcontrol__measurement
        ->flow_mech__stockcontrol__measurement_submit
        ->test_mech__stockcontrol__measurement_submit_ch11n
    ->flow_mech__stockcontrol__stockcheck
        ->flow_mech__stockcontrol__stockcheck_submit($location_names->[0])
        ->test_mech__stockcontrol__stockcheck_submit_ch11n
    ->flow_mech__stockcontrol__stockcheck_product
        ->flow_mech__stockcontrol__stockcheck_product_submit
        ->test_mech__stockcontrol__stockcheck_product_submit_ch11n
    ;
note 'Clear all test locations';
$flow1->data__location__destroy_test_locations;

done_testing;
1;

# WIP

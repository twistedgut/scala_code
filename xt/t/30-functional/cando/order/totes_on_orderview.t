#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::LoadTestConfig;
use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(:authorisation_level
                                   :shipment_item_status
                                   :container_status
                              );
use XTracker::Database qw(:common);
use Test::XT::Data::Container;

test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection',
        'Customer Care/Order Search',
        'Customer Care/Customer Search',
    ]},
    dept => 'Distribution'
});
$framework->mech->force_datalite(1);

test_prefix("Setup: order shipment");

my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 3,
});
my $order_data = $framework->flow_db__fulfilment__create_order_picked(
    channel  => $channel,
    products => $pids,
);

test_prefix("OrderView");
$framework->flow_mech__customercare__orderview($order_data->{order_object}->id);

my @items = @{$framework->mech->as_data()->{shipment_items}};

foreach my $item (@items) {
    my ($product_id, $size_id) = split(/-/, $item->{SKU});

    my $shipment_item = $framework->schema->resultset('Public::ShipmentItem')->search({
        'me.shipment_id' => $order_data->{shipment_object}->id,
        'variant.product_id' => $product_id,
        'variant.size_id' => $size_id,
    },
    {
        join => 'variant'
    })->first;

    is ($item->{'Status'}, $shipment_item->shipment_item_status->status, "shipment item shows correct status");
    is ($item->{'Container'}, $shipment_item->container_id, "shipment item shows correct container");
}


done_testing();

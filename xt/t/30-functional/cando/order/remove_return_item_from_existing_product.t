#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Data::Dump qw/pp/;
use FindBin::libs;



use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Constants::FromDB qw(
                                :authorisation_level
                                :shipment_item_status
                            );
use Test::XTracker::RunCondition dc => 'DC1';

my ($channel, $pids) = Test::XTracker::Data->grab_products({
    how_many                  => 1,
    force_create              => 1,
    ensure_stock_all_variants => 1,
});
my (undef, $variants) = Test::XTracker::Data->grab_multi_variant_product({
    channel                   => $channel,
    ensure_stock              => 1,
    ensure_stock_all_variants => 1,
    live                      => 1,
});


my @test_variants = ($variants->[0], $variants->[1]);

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::CustomerCare',
    ],
);

$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Order Search',
    ]},
    dept => 'Customer Care'
});

my $mech = $framework->mech;
$mech->force_datalite(1);

my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
        pids => \@test_variants,
        attrs => [
            { price => 100.00 },
            { price => 100.00 },
        ],
    });

note "order_nr: ". $order->order_nr;
note "orders_id: ". $order->id;

my $shipment = $order->shipments->first;

note "shipment_id to create rma :". $shipment->id;

$mech->order_nr($order->order_nr);
$mech->test_create_rma($shipment, 'exchange',undef,1);

my $return = $shipment->discard_changes->returns->first;

my $return_item_first  = $return->return_items->first;

$mech->test_add_rma_items($return, 'exchange',1);

$mech->test_remove_rma_items($return_item_first);

my $return_item = $return->return_items->search({
      id => {'!=' => $return_item_first->id}
    })->first;

ok($return_item->exchange_shipment_item->shipment_item_status_id != $SHIPMENT_ITEM_STATUS__CANCELLED, "Cannot have an return awaiting item with canceled exhange item");

done_testing;




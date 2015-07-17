#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Mechanize;

# go get some pids relevant to the db I'm using - channel is for test context
my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
    how_many_variants => 2,
});


my ($exchange_order, $order_hash) = Test::XTracker::Data->create_db_order({
    pids => $pids,
    attrs => [
        { price => 100.00 },
        { price => 250.00 },
    ],
});



Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns In', 1);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns QC', 1);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Putaway', 1);
Test::XTracker::Data->set_department('it.god', 'Customer Care');

my $mech = Test::XTracker::Mechanize->new;
$mech->do_login;

my $order_nr = $exchange_order->order_nr;
$mech->order_nr($order_nr);

ok(my $shipment = $exchange_order->shipments->first, "Sanity check: the order has a shipment");
note "Shipment Id: ".$shipment->id;

$mech->order_nr($order_nr);

my $return;
$mech->test_create_rma($shipment, 'exchange')
    ->test_exchange_size_change_order( $exchange_order, $return = $shipment->returns->first );

done_testing;

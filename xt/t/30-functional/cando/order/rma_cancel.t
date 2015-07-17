#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use Data::Dump qw/pp/;
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Mechanize;

my $channel = Test::XTracker::Data->channel_for_business(name=>'nap');
my $pids = Test::XTracker::Data->find_or_create_products({
    channel_id => $channel->id,
    how_many => 2,
    how_many_variants => 2,
});

Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns In', 1);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns QC', 1);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Putaway', 1);
Test::XTracker::Data->set_department('it.god', 'Customer Care');

my $mech = Test::XTracker::Mechanize->new;
$mech->do_login;

# test_{create,cancel}_rma expect a second arg to test for exchanges, so the
# second iteration in this loop will create an rma for exchanges
for my $type ( q{}, 'exchange' ) {
    my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        attrs => [
            { price => 100.00 },
            { price => 250.00 },
        ],
    });
    note "order_nr: ". $order->order_nr;
    note "orders_id: ". $order->id;
    my $shipment = $order->shipments->first;

    $mech->order_nr($order->order_nr);

    $mech->test_create_rma($shipment, $type);
    $mech->test_cancel_rma($shipment->returns->first, $type);
}

done_testing;

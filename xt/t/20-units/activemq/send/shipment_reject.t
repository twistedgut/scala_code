#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XT::Data::Container;
use Test::XTracker::MessageQueue;
use Test::XTracker::Hacks::TxnGuardRollback;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw( :shipment_item_status );
use List::Util qw(first);
use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema' );

my $amq = Test::XTracker::MessageQueue->new({schema=>$schema});
isa_ok( $amq, 'Test::XTracker::MessageQueue' );

my $channel = Test::XTracker::Data->get_local_channel();

my $pids = Test::XTracker::Data->find_or_create_products({
    channel_id  => $channel->id(),
    how_many    => 5,
});

my $queue = config_var('WMS_Queues','wms_fulfilment');

note "Using Queue: $queue";

$amq->clear_destination($queue);

# set up the shipment

my $txn = $schema->txn_scope_guard;

my $shipment = Test::XTracker::Data->create_shipment();

throws_ok {
    $amq->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentReject',{})
} qr{needs a shipment_id}, 'dies w/o shipment_id';

throws_ok {
    $amq->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentReject',{ shipment_id => 10+$shipment->id })
} qr{valid shipment_id}, 'dies w/ wrong shipment_id';

lives_ok {
    $amq->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentReject',{ shipment_id => $shipment->id })
} 'lives w/ empty shipment';

my @containers = Test::XT::Data::Container->get_unique_ids( { how_many => 2 } ) ;

my ($order) = Test::XTracker::Data->create_db_order({pids => $pids});
$shipment = $order->link_orders__shipments->first->shipment;

my %expected_containers;

my $client_code = $channel->client()->get_client_code();

foreach my $pid (@$pids) {
    my $item = $shipment->search_related('shipment_items',{
        variant_id => $pid->{variant_id},
    },{ rows => 1})->single;

    $pid->{container} = shift @containers;push @containers,$pid->{container};

    $expected_containers{$pid->{container}} //= {
        container_id => "$pid->{container}",
        items => [],
    };

    $item->pick_into($pid->{container}, $APPLICATION_OPERATOR_ID);
    push @{$expected_containers{$pid->{container}}->{items}},{
        sku     => $item->get_true_variant->sku,
        quantity=> 1,
        client  => $client_code,
    };
}
$_->{items} = bag(@{$_->{items}}) for values %expected_containers;

$amq->clear_destination($queue);

lives_ok {
    $amq->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentReject',{ shipment_id => $shipment->id })
} 'lives with correct shipment';


$amq->assert_messages({
    destination => $queue,
    assert_header => superhashof({
        type => 'shipment_reject',
    }),
    assert_body => {
        '@type' => 'shipment_reject',
        version => '1.0',
        shipment_id => 's-'.$shipment->id,
        containers => bag(values %expected_containers),
    },
}, "Message matched")
    or diag p %expected_containers;

$txn->rollback;

done_testing();

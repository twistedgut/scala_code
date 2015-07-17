#!/usr/bin/env perl
use NAP::policy "tt", qw( test );

use Test::XTracker::RunCondition    dc => [ qw( DC1 DC2 ) ];

use Test::XTracker::MessageQueue;
use Test::Exception;
use Test::XT::Data;

my $amq = Test::XTracker::MessageQueue->new();
my $schema  = Test::XTracker::Data->get_schema;
my $factory = $amq->producer;

isa_ok( $amq, 'Test::XTracker::MessageQueue' );
isa_ok( $schema, 'XTracker::Schema' );
isa_ok( $factory, 'Net::Stomp::Producer' );

my $channel = $schema->resultset('Public::Channel')->search({
    name => 'JIMMYCHOO.COM',
})->first;

isa_ok( $channel, "XTracker::Schema::Result::Public::Channel" );

my $msg_type = 'XT::DC::Messaging::Producer::Return::RequestSuccess';
my $queue = "/queue/returns-ack-mercury";

ok( $queue, "I have a queue" );

note "testing AMQ message type: $msg_type into queue: $queue";

my $order_obj = Test::XT::Data->new_with_traits(
    traits => [ 'Test::XT::Data::Order', 'Test::XT::Data::Return' ]
);

my $order_objects = $order_obj->dispatched_order( channel => $channel );
my $order = $order_objects->{order_object};
my $shipment_id = $order_objects->{shipment_id};

my $return = $order_obj->new_return( {
    shipment_id => $shipment_id
} );

my $data = {
    return              => $return,
    return_request_date => "2014-03-01T14:30:00.000+0000"
};

my $expected = {
    status                  => "success",
    channel                 => $channel->web_name,
    returnRequestDate     => "2014-03-01T14:30:00.000+0000",
    returnCreationDate    => $return->creation_date->set_time_zone('UTC')->strftime("%FT%H:%M:%S%z"),
    returnExpiryDate      => $return->expiry_date->set_time_zone('UTC')->strftime("%FT%H:%M:%S%z"),
    orderNumber            => $return->link_order__shipment->order->order_nr,
    rmaNumber              => $return->rma_number,
};

foreach my $return_item ( $return->return_items->all ) {
    my $item = {
        sku                 => $return_item->shipment_item->variant->get_third_party_sku,
        externalLineItemId  => $return_item->shipment_item->pws_ol_id
    };
    if ( $return_item->exchange_shipment_item_id ) {
        $item->{exchangeSku} = $return_item->exchange_shipment_item->variant->get_third_party_sku;
    }
    push @{ $expected->{returnItems} }, $item;
}

# Clear the message queue
$amq->clear_destination($queue);

lives_ok ( sub {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }, "Can send valid message" );

$amq->assert_messages({
    destination => $queue,
    assert_header => superhashof({
        type => 'return_request_ack',
    }),
    assert_body => superhashof( $expected ),
}, 'Message contains the correct return request error data' );

done_testing;


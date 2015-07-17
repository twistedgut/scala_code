#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::MessageQueue;
use Test::Exception;
use XTracker::Config::Local qw/config_var/;

my $amq = Test::XTracker::MessageQueue->new;
my $schema  = Test::XTracker::Data->get_schema;
my $factory = $amq->producer;

isa_ok( $amq, 'Test::XTracker::MessageQueue' );
isa_ok( $schema, 'XTracker::Schema' );
isa_ok( $factory, 'Net::Stomp::Producer' );

my $msg_type = 'XT::DC::Messaging::Producer::Stock::ThirdPartyUpdate';
my $queue = config_var('Producer::Stock::ThirdPartyUpdate', 'destination');

note "testing AMQ message type: $msg_type into queue: $queue";

my $business = $schema->resultset('Public::Business')->search({
    name => 'JIMMYCHOO.COM',
})->single;
my $status   = 'Sellable';
my $location = 'DC1';
my $quantity = '100';
my $sku      = 'ATESTSKU123';

my $data = {
    business => $business,
    status => $status,
    location => $location,
    quantity => $quantity,
    sku => $sku,
};

$amq->clear_destination($queue);

lives_ok {
    $factory->transform_and_send(
        $msg_type,
        $data,
    )
}
"Can send valid message";

$amq->assert_messages({
    destination => $queue,
    assert_header => superhashof({
        type => 'ThirdPartyStockUpdate',
    }),
    assert_body => superhashof({
        stock_product => {
            stock => {
                status   => $status,
                location => $location,
                quantity => $quantity,
            },
            SKU => $sku,
        },
    }),
}, 'Message contains the correct stock update data' );

done_testing;


#!/usr/bin/env perl
use NAP::policy "tt", qw( test );

use Test::XTracker::MessageQueue;
use Test::Exception;

my $amq = Test::XTracker::MessageQueue->new;
my $schema  = Test::XTracker::Data->get_schema;
my $factory = $amq->producer;

isa_ok( $amq, 'Test::XTracker::MessageQueue' );
isa_ok( $schema, 'XTracker::Schema' );
isa_ok( $factory, 'Net::Stomp::Producer' );

my $channel = $schema->resultset('Public::Channel')->search({
    name => 'JIMMYCHOO.COM',
})->first;

isa_ok( $channel, "XTracker::Schema::Result::Public::Channel" );

my $msg_type = 'XT::DC::Messaging::Producer::Return::RequestError::JC';
my $queue = "queue/returns-ack-mercury";

ok( $queue, "I have a queue" );

note "testing AMQ message type: $msg_type into queue: $queue";

my $data = {
    original_message    => {
        returnRequestDate   => "2014-03-01T14:30:00.000+0000",
        orderNumber         => "JC123",
        channel             => $channel->web_name,
    },
    errors               => "Something went wrong",
};

$amq->clear_destination($queue);

lives_ok ( sub {
        $factory->transform_and_send(
            $msg_type,
            $data,
        )
    }, "Can send valid message" );

my $expected = $data->{original_message};
$expected->{error} = $data->{errors};
$expected->{status} = "failure";

$amq->assert_messages({
    destination => $queue,
    assert_header => superhashof({
        type => 'return_request_ack',
    }),
    assert_body => superhashof( $expected ),
}, 'Message contains the correct return request error data' );

done_testing;


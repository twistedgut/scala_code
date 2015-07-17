#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local qw/ config_var /;
use XTracker::Constants qw( :application );
use Data::Dump qw/pp/;

=head2 TEST SUMMARY

- Create a new order.
- Create an AMQ message
- Validate that it's sane

=cut


# ============= PREPARE QUEUE

my $amq = Test::XTracker::MessageQueue->new;

isa_ok( $amq, 'Test::XTracker::MessageQueue' );

my $schema = Test::XTracker::Data->get_schema;

isa_ok( $schema, 'XTracker::Schema' );

my $factory = $amq->producer;

isa_ok( $factory, 'Net::Stomp::Producer' );

my $msg_type = 'XT::DC::Messaging::Producer::Order::ImportStatus';
my $instance    = config_var('XTracker','instance');

my $queue = "/queue/".lc($instance)."/jc/order-status";
$amq->clear_destination( $queue );

ok( defined $queue && $queue ne '', 'Queue name has been defined' );

note "testing AMQ message type: $msg_type into queue: $queue";

# ============= PREPARE MESSAGE

# Create Order.

my( $channel, $pids ) = Test::XTracker::Data->grab_products(
    {
        how_many => 1,
        dont_ensure_stock => 1,
        channel => 'jc',
    }
);

isa_ok( $channel, 'XTracker::Schema::Result::Public::Channel' );
isa_ok( $pids, 'ARRAY' );

my ( $order ) = Test::XTracker::Data->create_db_order(
    {
        pids => $pids,
    }
);

isa_ok( $order, 'XTracker::Schema::Result::Public::Orders' );

my $data = {
              o_id            => $order->order_nr,
              successful      => '1',
              message         => { channel => "JC-${instance}" },
              error => {
                 original   => 'Original Complete Error Stack Trace',
                 summary => 'A simpler version of the above that could be given to JC',
                 message   => 'A more readable version of the original message payload',
              },
              duplicate => '1',
           };

# ============= SEND MESSAGE

note "\$data = '" . pp( $data ) . "'\n";

lives_ok {
    $factory->transform_and_send(
        $msg_type,
        $data,
    )
}
"Can send valid message";

# ============= VALIDATE MESSAGE


$amq->assert_messages({
    destination => $queue,
    assert_header => superhashof({
        type => 'OrderImportStatus',
    }),
    assert_body => superhashof($data),
}, 'Message contains the correct data and is going in the correct queue'
);

done_testing;

#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local qw/ config_var /;
use XTracker::Constants::FromDB qw( :bulk_reimbursement_status );
use XTracker::Constants qw( :application );
use Data::Dump qw/pp/;

=head2 TEST SUMMARY

- Create a new order.
- Create a new bulk_reimbursement entry, with the single associated order.
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


my $msg_type = 'XT::DC::Messaging::Producer::Order::Reimbursement';
my $queue = config_var('Producer::Order::Reimbursement', 'destination');

ok( defined $queue && $queue ne '', 'Queue name has been defined' );

$amq->clear_destination($queue);

note "testing AMQ message type: $msg_type into queue: $queue";

# ============= PREPARE MESSAGE

# Create Order.

my( $channel, $pids ) = Test::XTracker::Data->grab_products(
    {
        how_many => 1,
        dont_ensure_stock => 1,
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

# Populate the bulk_reimbursement and link_bulk_reimbursement__orders tables.

my $bulk_reimbursement = $schema->resultset('Public::BulkReimbursement')->create(
    {
        'operator_id'                       => $APPLICATION_OPERATOR_ID,
        'channel_id'                        => $order->channel_id,
        'bulk_reimbursement_status_id'      => $BULK_REIMBURSEMENT_STATUS__PENDING,
        'credit_amount'                     => 25,
        'reason'                            => 'Test Reason',
        'send_email'                        => 1,
        'email_subject'                     => 'Test Email Subject',
        'email_message'                     => 'Test Email Body',
        'link_bulk_reimbursement__orders'   => [ { 'order_id' => $order->id } ],
    }
);

isa_ok( $bulk_reimbursement, 'XTracker::Schema::Result::Public::BulkReimbursement' );

my $data = { reimbursement_id => $bulk_reimbursement->id };

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
        type => 'bulk',
    }),
    assert_body => superhashof({
        'reimbursement_id' => $bulk_reimbursement->id,
    }),
}, 'Message contains the correct data and is going in the correct queue'
);

done_testing;

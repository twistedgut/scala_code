#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Data::Dump qw/pp/;

use Test::XTracker::Data;
use Test::XTracker::RunCondition    export => qw( $distribution_centre );
use Test::XTracker::MessageQueue;
use XTracker::Constants::FromDB     qw(
                                        :bulk_reimbursement_status
                                        :note_type
                                        :renumeration_type
                                        :renumeration_class
                                    );
use XTracker::Constants qw( :application );
use XTracker::Config::Local qw/ config_var /;
use DateTime;

my $config = {
    DC1 => { req_path => '/queue/order-refund/dc1', queue => '/queue/refund-integration-nap-intl' },
    DC2 => { req_path => '/queue/order-refund/dc2', queue => '/queue/refund-integration-nap-am' },
    DC3 => { req_path => '/queue/order-refund/dc3', queue => '/queue/refund-integration-nap-apac' },
}->{ $distribution_centre };

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;

XT::DC::Messaging->log->disable('error','debug');

my $dc_name = config_var('DistributionCentre','name');
my $order_refunds_queue_name = $config->{req_path};

isa_ok( $amq, 'Test::XTracker::MessageQueue' );

my $schema = Test::XTracker::Data->get_schema;

isa_ok( $schema, 'XTracker::Schema' );

# ============= Create Order.

my( $channel, $pids ) = Test::XTracker::Data->grab_products(
    {
        how_many => 1,
        dont_ensure_stock => 1,
    }
);

isa_ok( $channel, 'XTracker::Schema::Result::Public::Channel' );
isa_ok( $pids, 'ARRAY' );

my $refund_integration_queue_name = '/queue/refund-integration-'.lc($channel->web_name);

my ( $order ) = Test::XTracker::Data->create_db_order(
    {
        pids => $pids,
    }
);

isa_ok( $order, 'XTracker::Schema::Result::Public::Orders' );
my $shipment = $order->get_standard_class_shipment;

note 'orders.id: ' . $order->id;

# ============= Populate the bulk_reimbursement and link_bulk_reimbursement__orders tables.

my $invoice_reason = $schema->resultset('Public::RenumerationReason')->get_compensation_reasons->first;

my $bulk_reimbursement = $schema->resultset('Public::BulkReimbursement')->create(
    {
        'operator_id'                       => $APPLICATION_OPERATOR_ID,
        'channel_id'                        => $order->channel_id,
        'bulk_reimbursement_status_id'      => $BULK_REIMBURSEMENT_STATUS__PENDING,
        'credit_amount'                     => 25,
        'renumeration_reason_id'            => $invoice_reason->id,
        'reason'                            => 'Test Reason',
        'send_email'                        => 1,
        'email_subject'                     => 'Test Email Subject',
        'email_message'                     => 'Test Email Body',
        'link_bulk_reimbursement__orders'   => [ { 'order_id' => $order->id } ],
    }
);

isa_ok( $bulk_reimbursement, 'XTracker::Schema::Result::Public::BulkReimbursement' );

note 'bulk_reimbursement.id: ' . $bulk_reimbursement->id;

# ============= Send to the queue.

my $queue_name = $order_refunds_queue_name;

my ($payload,$header) = test_payload( $bulk_reimbursement->id );

note "about to send request to '$queue_name' ... ". p($payload);

$amq->clear_destination($refund_integration_queue_name);

my $res = $amq->request( $app, $queue_name, $payload, $header );

ok( $res->is_success , "Result From sending to '$queue_name' queue" );

note $res->as_string unless $res->is_success;

# ============= Test bulk_reimbursement_status_id

$bulk_reimbursement->discard_changes; # refresh the object from the database.
ok( $bulk_reimbursement->bulk_reimbursement_status_id eq $BULK_REIMBURSEMENT_STATUS__DONE, 'bulk_reimbursement_status_id updated to DONE' );

# ============= Check operator received a message.

my $datetime_parser = $schema->storage->datetime_parser;
my $message         = $schema->resultset('Operator::Message')->search( {
    subject         => 'Bulk Reimbursement Results',
    body            => { '-like' => '%' . $order->order_nr . '%' },
    created         => { '>', $datetime_parser->format_datetime( DateTime->now( time_zone => 'local' )->subtract( minutes => 1 ) ) },
    recipient_id    => $APPLICATION_OPERATOR_ID,
    sender_id       => $APPLICATION_OPERATOR_ID,
    viewed          => 0,
    deleted         => 0,
} );

isa_ok( $message, 'DBIx::Class::ResultSet', '$message' );

ok( $message->count == 1, 'Operator received message' );

# ============= Check for an order note.

my $order_note = $schema->resultset('Public::OrderNote')->search( {
    orders_id       => $order->id,
    note            => sprintf(
                        'Store Credit Applied - %0d %s %s',
                        25,
                        $order->currency->currency,
                        $invoice_reason->reason . ' - ' . 'Test Reason'
                    ),
    note_type_id    => $NOTE_TYPE__FINANCE,
    operator_id     => $APPLICATION_OPERATOR_ID,
} );

isa_ok( $order_note, 'DBIx::Class::ResultSet', '$order_note' );

ok( $order_note->count == 1, 'Order note created' );

# ============= Check the Refund Invoice.

my $invoice = $shipment->search_related( 'renumerations', {
    renumeration_type_id    => $RENUMERATION_TYPE__STORE_CREDIT,
    renumeration_class_id   => $RENUMERATION_CLASS__GRATUITY,
} )->first;
isa_ok( $invoice, 'XTracker::Schema::Result::Public::Renumeration', "Found a Store Credit Gratuity Invoice" );
is( $invoice->misc_refund, '25.000', "Invoice's 'misc_refund' field is as expected" );
cmp_ok( $invoice->currency_id, '==', $order->currency_id, "Invoice's Currency is the same as for the Order" );
ok( defined $invoice->renumeration_reason_id, "Invoice's 'renumeration_reason_id' field is populated" );
cmp_ok( $invoice->renumeration_reason_id, '==', $invoice_reason->id, "and for the expected Reason" );

# ============= Test refund integration queue.

my $queue_message = {
    '@type'         => 'CustomerCreditRefundRequestDTO',
    orderId         => $order->order_nr,
    customerId      => $order->customer->is_customer_number,
    notes           => 'Gratuity',
    createdBy       => 'xt-' . $APPLICATION_OPERATOR_ID,
    refundCurrency  => $order->currency->currency,
    refundValues    => [
                        superhashof({
                            '@type' => 'CustomerCreditRefundValueRequestDTO',
                            refundValue => 25,
                        }),
                    ],
};

$amq->assert_messages({
    destination => $refund_integration_queue_name,
    assert_header => superhashof({
        type => 'RefundRequestMessage',
    }),
    assert_body => superhashof($queue_message),
}, "$refund_integration_queue_name queue is being populated correctly." );

# ============= ALL DONE

done_testing;

sub test_payload {
    my ( $reimbursement_id ) = @_;

    return {
        #'@type'             => 'bulk',
        'reimbursement_id'  => $reimbursement_id,
    },{
        type => 'bulk',
    }
}


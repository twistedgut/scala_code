#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 ) ];

use Test::NAP::Messaging::Helpers 'atleast';
use Test::XTracker::MessageQueue;
use Test::XTracker::Data;
use Test::XTracker::Mechanize;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants::FromDB     qw( :renumeration_type );

my $amq     = Test::XTracker::MessageQueue->new;

my $channel     = Test::XTracker::Data->get_local_channel();

my @pids        = sort { $a->id <=> $b->id } map { $_->{product} } @{
    (Test::XTracker::Data->grab_products({
        channel => $channel,
        how_many => 2,
        how_many_variants => 2,
        ensure_stock_all_variants => 1,
    }))[1] };
my @pid1_vars   = $pids[0]->variants->search( {},{ order_by => 'me.id' } )->all;
my @pid2_vars   = $pids[1]->variants->search( {},{ order_by => 'me.id' } )->all;

# Use the DC's own country so that Duties will get Charged and Tax will get refunded.
# Although Duties wouldn't be on the Shipment Item for a Domestic order normally it
# does test that the right action is being taken with regards to refunds and charges
my $domestic_addr   = Test::XTracker::Data->order_address( { address=>'create', country => config_var( 'DistributionCentre', 'country' ) } );

# We need an rma to test with exchange instead of returns.
my $exchange_order = Test::XTracker::Data->create_db_order({
    items => {
        $pid1_vars[1]->sku => { price => 250.00, tax => 10, duty => 25 },
        $pid2_vars[0]->sku => { price => 100.00, tax => 10, duty => 25 },
    },
    invoice_address_id  => $domestic_addr->id,
});


Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Returns Pending', 2);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns In', 1);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Returns QC', 1);
Test::XTracker::Data->grant_permissions('it.god', 'Goods In', 'Putaway', 1);
Test::XTracker::Data->set_department('it.god', 'Customer Care');

my $mech = Test::XTracker::Mechanize->new;
$mech->do_login;

$mech->order_nr($exchange_order->order_nr);

my $queue   = $mech->nap_order_update_queue_name();
$amq->clear_destination( $queue );


ok(my $shipment = $exchange_order->shipments->first, "Sanity check: the order has a shipment");

$mech->order_nr($exchange_order->order_nr);

my $return;
$mech->test_create_rma($shipment, 'exchange')
     ->test_exchange_pending($return = $shipment->returns->first);

cmp_ok( $shipment->shipment_email_logs->count, '==', 1, 'There is 1 email logged against the shipment' );

$mech->test_convert_from_exchange( $return );
cmp_ok( $shipment->shipment_email_logs->count, '==', 2, 'There are 2 emails logged against the shipment' );

my $invoice = $return->renumerations->search( {}, { order_by => 'id DESC' } )->first;
cmp_ok( $invoice->renumeration_type_id, '==', $RENUMERATION_TYPE__STORE_CREDIT, "Renumeration Type is Store Credit" );
cmp_ok( $invoice->grand_total, '==', 260, "Invoice Total is 260, which is unit price + tax" );

$amq->assert_messages({
    destination => $queue,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        '@type' => 'order',
        orderNumber => $shipment->order->order_nr,
        rmaNumber  => $return->rma_number,
        orderItems => bag(
            all(superhashof({
                sku => $pid1_vars[1]->sku,
                returnReason => 'PRICE',
                status => 'Return Pending',
            }),code(sub{! exists $_->{exchangeSku}}),
            ),
            superhashof({
                sku => $pid2_vars[0]->sku,
                status => 'Dispatched',
            }),
        ),
    }),
    assert_count => atleast(1),
}, 'order status sent on AMQ (refund)');
$amq->clear_destination( $queue );

$mech->test_convert_to_exchange( $return, { should_send_email => 'no' } );
cmp_ok( $shipment->shipment_email_logs->count, '==', 2, 'There are still 2 emails logged against the shipment' );
# check Duty has been Charged
$invoice    = $return->renumerations->search( {}, { order_by => 'id DESC' } )->first;
cmp_ok( $invoice->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "Renumeration Type is Card Debit" );
cmp_ok( $invoice->grand_total, '==', 25, "Invoice Total is 25, which is duty" );

$amq->assert_messages({
    destination => $queue,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        '@type' => 'order',
        orderNumber => $shipment->order->order_nr,
        rmaNumber  => $return->rma_number,
        orderItems => bag(
            superhashof({
                sku => $pid1_vars[1]->sku,
                returnReason => 'PRICE',
                status => 'Return Pending',
                exchangeSku => $pid1_vars[0]->sku,
            }),
            superhashof({
                sku => $pid2_vars[0]->sku,
                status => 'Dispatched',
            }),
        ),
    }),
    assert_count => atleast(1),
}, 'order status sent on AMQ (exchange)');
$amq->clear_destination( $queue );

done_testing;

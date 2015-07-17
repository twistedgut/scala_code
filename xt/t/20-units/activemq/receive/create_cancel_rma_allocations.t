#!/usr/bin/env perl

=head1 TEST PLAN

DCA-2359

    * Request an RMA for an exchange via the website
    * Wait for RMA to be generated in XT
    * Check the exchange shipment has been allocated
    * Cancel the request
    * RMA and exchange allocation cancelled in XT

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XT::ActiveMQ;
use Test::XTracker::MessageQueue;
use XTracker::Constants::FromDB qw(
    :allocation_status
    :allocation_item_status
    :return_status
    :shipment_status
);

use Test::XTracker::RunCondition prl_phase => 'prl', export => qw( $distribution_centre );

# We only use PRLs in DC2 at the moment, but theoretically this should work the same in
# all DCs
my $config = {
    DC1 => { req_path => '/queue/dc1-nap-returns', queue => '/queue/nap-intl-orders' },
    DC2 => { req_path => '/queue/dc2-nap-returns', queue => '/queue/nap-am-orders'   },
    DC3 => { req_path => '/queue/dc3-nap-returns', queue => '/queue/nap-apac-orders' },
}->{ $distribution_centre };

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;

my $channel = Test::XTracker::Data->channel_for_business( name => 'nap' );
my $pids = Test::XTracker::Data->find_or_create_products({
    how_many    => 1,
    channel_id  => $channel->id,
});

my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
    pids  => $pids,
    attrs => [
        { price => 100.00 },
    ],
});

my ($req_payload, $req_header) = Test::XT::ActiveMQ::rma_req_message($order,
    [
        {
            "returnReason"          => "POOR_QUALITY",
            "itemReturnRequestDate" => "2009-09-01 12:52:19 +0100",
            "faultDescription"      => "The zip is broken",
            "sku"                   => $pids->[0]->{sku},
            "exchangeSku"           => $pids->[0]->{sku},
        },
    ]
);
my $res = $amq->request(
    $app,
    $config->{'req_path'},
    $req_payload,
    $req_header,
);
ok( $res->is_success, "Result from sending to /dc?-nap-returns queue, 'return_request' action" );

my $shipment = $order->get_standard_class_shipment;
my $return = $shipment->returns->not_cancelled->first;

ok ($return, "Return was created") or die;
my $rma_number = $return->rma_number;
note 'rma_number : '. $return->rma_number;
my $exchange_shipment = $return->exchange_shipment;

ok ($exchange_shipment, "Return has an associated exchange shipment");
note "Exchange shipment id: ".$exchange_shipment->id;

is ($exchange_shipment->allocations->count, 1, "Exchange shipment has an allocation");
my $exchange_allocation = $exchange_shipment->allocations->first;
is ($exchange_allocation->status_id, $ALLOCATION_STATUS__REQUESTED,
    "Allocation status is 'requested'");

is ($exchange_allocation->allocation_items->count, 1,
    "Exchange allocation has one item");
my $exchange_allocation_item = $exchange_allocation->allocation_items->first;
is ($exchange_allocation_item->status_id, $ALLOCATION_ITEM_STATUS__REQUESTED,
    "Allocation item status is 'requested'");

# Cancel the return
my ($cancel_payload, $cancel_header) = Test::XT::ActiveMQ::rma_cancel_message(
    $return,
    [ { "sku" => $pids->[0]->{sku} } ]
);
$res = $amq->request(
    $app,
    $config->{'req_path'},
    $cancel_payload,
    $cancel_header
);
ok( $res->is_success, "Result from sending to /dc?-nap-returns queue, 'cancel_return_items' action" );

$return->discard_changes;
$exchange_shipment->discard_changes;
$exchange_allocation->discard_changes;
$exchange_allocation_item->discard_changes;

# Check that the return and the exchange shipment have been cancelled
is ($return->return_status_id, $RETURN_STATUS__CANCELLED,
    "Return status is 'cancelled'");
is ($exchange_shipment->shipment_status_id, $SHIPMENT_STATUS__CANCELLED,
    "Shipment status is 'cancelled'");

# Check that the allocation status is still requested (there's no new status to
# use for allocations at this point) and the allocation_item status has changed
# to cancelled.
is ($exchange_allocation->status_id, $ALLOCATION_STATUS__REQUESTED,
    "Allocation status is 'requested'");
is ($exchange_allocation_item->status_id, $ALLOCATION_ITEM_STATUS__CANCELLED,
    "Allocation item status is 'cancelled'");

done_testing;



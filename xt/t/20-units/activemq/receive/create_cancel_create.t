#!/usr/bin/env perl

=head1 TEST PLAN

DCS-2184

    * Request an RMA for refund via the website
    * Wait for RMA to be generated in XT
    * Cancel the request
    * RMA and refund cancelled in XT
    * Request same item again for refund via website
    * RMA created with a 0 refund on item in XT

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::XT::ActiveMQ;

use XTracker::Constants::FromDB qw/
  :correspondence_templates
/;

use Test::XTracker::RunCondition export => qw( $distribution_centre );

my $config = {
    DC1 => { req_path => '/queue/dc1-nap-returns', queue => '/queue/nap-intl-orders' },
    DC2 => { req_path => '/queue/dc2-nap-returns', queue => '/queue/nap-am-orders'   },
    DC3 => { req_path => '/queue/dc3-nap-returns', queue => '/queue/nap-apac-orders' },
}->{ $distribution_centre };

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;

my $channel = Test::XTracker::Data->channel_for_business(name=>'nap');
my $pids = Test::XTracker::Data->find_or_create_products({
    how_many => 2,
    channel_id => $channel->id,
});

my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
    pids => $pids,
    attrs => [
        { price => 100.00 },
        { price => 250.00 },
    ],
});


# for each pid make sure there's stock
foreach my $item (@{$pids}) {
    Test::XTracker::Data->ensure_variants_stock($item->{pid});
}

#Test::XTracker::Data->ensure_stock(48498, 99);

my ($req_payload,$req_header) = Test::XT::ActiveMQ::rma_req_message($order,
    [
        {
            "returnReason" => "POOR_QUALITY",
            "itemReturnRequestDate" => "2009-09-01 12:52:19 +0100",
            "faultDescription" => "The zip is broken",
            "sku" => $pids->[0]->{sku}, #"48498-098",
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

# Check that the original return has a non-zero refund
note "return id : ". $return->id;
ok(my $renum = $return->renumerations->first, "Return has a refund")
  or die "No refund!";

my $renum_id = $renum->id;

my $orig_value = $renum->renumeration_items->get_column('unit_price')->sum +
                 $renum->renumeration_items->get_column('tax')->sum +
                 $renum->renumeration_items->get_column('duty')->sum +
                 $renum->shipping;

# Cancel it and re-request a new return

my ($cancel_payload, $cancel_header) = Test::XT::ActiveMQ::rma_cancel_message(
    $return,
    [ { "sku" => $pids->[0]->{sku} } ]
);
$res = $amq->request(
    $app,
    $config->{'req_path'},
    $cancel_payload,
    $cancel_header,
);
ok( $res->is_success, "Result from sending to /dc?-nap-returns queue, 'cancel_return_items' action" );

$res    = $amq->request(
    $app,
    $config->{'req_path'},
    $req_payload,
    $req_header,
);
ok( $res->is_success, "Result from sending to /dc?-nap-returns queue, 'return_request' action" );

$shipment->discard_changes;
$return = $shipment->returns->not_cancelled->first;

ok ($return, "Return was created") or die;
note 'rma_number : '. $return->rma_number;
isnt($return->rma_number, $rma_number, "Got a new RMA");

note "return id   : ". $return->id;
note "shipment id : ". $shipment->id;

if (!$shipment->is_domestic) {
    # Check that the original return has a non-zero refund
    ok($renum = $return->renumerations->not_cancelled->first, "Return has a not cancelled refund")
    #ok($renum = $return->renumerations->first, "Return has a not cancelled refund")
      or die "No refund!";

    note 'returns renumeration : '. $renum->id;

    isnt($renum->id, $renum_id, "Got a new renumeration");

    my $new_value = $renum->renumeration_items->get_column('unit_price')->sum +
                    $renum->renumeration_items->get_column('tax')->sum +
                    $renum->renumeration_items->get_column('duty')->sum +
                    $renum->shipping;

    cmp_ok($new_value, '==', $orig_value, "New refund is for same amount as old one");

}

done_testing;



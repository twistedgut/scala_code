#!/usr/bin/env perl
use NAP::policy "tt", 'test';


use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local;
use Test::NAP::Messaging::Helpers 'napdate';
use Test::XT::ActiveMQ;
use XTracker::Constants::FromDB qw/
    :business
    :correspondence_templates
/;

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;
my $pws_request_date = "2009-09-01 12:52:19 +0100";
my $channel = Test::XTracker::Data->channel_for_business(id=>$BUSINESS__NAP);

my $pids = Test::XTracker::Data->find_or_create_products({
    channel_id => $channel->id,
    how_many => 2,
});
my $return_ref = $pids->[0];
my $exchange_ref = $pids->[1];
# Create an rma with one item
my $return = Test::XTracker::Data->create_rma({
    items => {
        $return_ref->{sku} => { price => 100.00 },
        $exchange_ref->{sku} => { price => 250.00, _no_return => 1 },
    },
});

Test::XTracker::Data->ensure_variants_stock($_->{pid}) for @$pids;

my $shipment = $return->shipment;

my $out_queue = config_var('Producer::PreOrder::TriggerWebsiteOrder','routes_map')->{$channel->web_name};

$amq->clear_destination($out_queue);

# Then a message with the other
my ($payload, $header) = Test::XT::ActiveMQ::rma_add_message($return, [ {
    "returnReason" => "POOR_QUALITY",
    "exchangeSku" => $pids->[1]{sku},
    "itemReturnRequestDate" => $pws_request_date,
    "faultDescription" => "The zip is still broken",
    "sku" => $exchange_ref->{sku},
}, ], $pws_request_date);

my $request_path = '/queue/'. lc(config_var('DistributionCentre', 'name')) . '-nap-returns';
my $res = $amq->request(
    $app,
    $request_path,
    $payload,
    $header,
);
ok( $res->is_success, "Result from sending to /queue/dc?-nap-returns, 'return_request' action" );

$amq->assert_messages({
    destination => $out_queue,
    assert_header => superhashof({
        type => 'OrderMessage',
    }),
    assert_body => superhashof({
        returnRefundType => 'CREDIT',
        returnExpiryDate => napdate($return->expiry_date),
        returnCreationDate     => napdate($return->creation_date),
        returnCancellationDate => napdate($return->cancellation_date),
        orderItems => bag(
            all(superhashof({
                sku => $return_ref->{sku},
                returnReason => 'PRICE',
            }),code(sub{!exists shift->{exchangeSku}})),
            superhashof({
                sku => $exchange_ref->{sku},
                exchangeSku => $exchange_ref->{sku},
                status => "Return Pending",
                returnReason => 'POOR_QUALITY',
            }),
        ),
    }),
    assert_count => 2, # Is this correct?? XT::Domain::Returns already
                       # sends updates, and ::Consumer::Returns *also*
                       # sends them!
}, 'order status sent on AMQ');

my $note = $return->return_notes->first;

ok($note, "Got a returns note added to shipment");
is( $note->note,
    "Created from Website request on $pws_request_date\n"
  . "$exchange_ref->{sku} - Fault Description: The zip is still broken",
    "Have return notes"
);



# Check that we logged an email - some way of checking the content would be
# nice, but the log coupled with the fact that the emails are rendered using
# STRICT => 1 means this test should be okay
cmp_ok(
  Test::XTracker::Data->get_schema->resultset('Public::ShipmentEmailLog')->search({
    shipment_id => $shipment->id,
    correspondence_templates_id => $CORRESPONDENCE_TEMPLATES__ADD_RETURN_ITEM
  })->count,
  '==',
  1,
  "Add Return Item email logged");

done_testing;



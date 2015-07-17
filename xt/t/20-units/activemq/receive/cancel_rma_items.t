#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::Config;
use Test::NAP::Messaging::Helpers 'napdate';
use Test::XT::ActiveMQ;
use XTracker::Constants::FromDB qw/
  :correspondence_templates
  :note_type
/;
use XTracker::Config::Local;
use XTracker::Constants '$APPLICATION_OPERATOR_ID';

my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;

my $schema  = Test::XTracker::Data->get_schema;
my $channel = Test::XTracker::Data->channel_for_business(name=>'nap');
# go get some pids relevant to the db I'm using - channel is for test context
my $pids = Test::XTracker::Data->find_or_create_products({
    how_many => 2,
    channel => $channel->id,
});

# for each pid make sure there's stock
foreach my $item (@{$pids}) {
    Test::XTracker::Data->ensure_variants_stock($item->{pid});
}

my $items = undef;
foreach my $pid (@{$pids}) {
    $items->{ $pid->{sku} } = { };
}
# Create an rma with two items, and cancel one.
my $return = Test::XTracker::Data->create_rma({
    items => $items
}, $pids);

my $shipment = $return->shipment;

# Then a message with the other
my ($payload, $header) = Test::XT::ActiveMQ::rma_cancel_message($return,
    [ { "sku" => $pids->[0]->{sku} } ]
);

my $res;
my $out_queue = config_var('Producer::PreOrder::TriggerWebsiteOrder','routes_map')->{$channel->web_name};
my $in_queue = Test::XTracker::Config->messaging_config->{'Consumer::NAPReturns'}{routes_map}{destination};

$amq->clear_destination($out_queue);

produces_return_note_ok( $return, sub {
    $res = $amq->request(
        $app,
        $in_queue,
        $payload,
        $header,
    );
}, 'Return item cancelled due to ARMA cancellation request from Website on ' . $payload->{returnCancelRequestDate} . ' for SKU: ' . $pids->[0]->{sku},
'Cancelling a single item' );

ok( $res->is_success, "Result from sending to /dc?-nap-returns queue, 'cancel_return_items' action" );

#my @items = $return->return_items;
my $item = $return->return_items->find_by_sku($pids->[1]->{sku})->discard_changes;

$amq->assert_messages({
    destination => $out_queue,
    assert_header => superhashof({
        type => 'OrderMessage',
    }),
    assert_body => superhashof({
        orderNumber => $shipment->order->order_nr,
        rmaNumber  => $return->rma_number,
        orderItems => bag(
            all(superhashof({
                sku => $pids->[0]->{sku},
                status => 'Dispatched',
            }),code(sub{!exists shift->{returnReason}})),
            superhashof({
                sku => $pids->[1]->{sku},
                returnReason => 'PRICE',
                returnCreationDate => napdate($item->creation_date),
                status => 'Return Pending',
                xtLineItemId => $item->shipment_item_id,
            }),
        ),
    }),
    assert_count => 2, # Is this correct?? XT::Domain::Returns already
                       # sends updates, and ::Consumer::Returns *also*
                       # sends them!
}, 'order status sent on AMQ')
  or diag($res->content);


# Check that we logged an email - content tested directly in t/retursne/email_*
cmp_ok(
  $schema->resultset('Public::ShipmentEmailLog')->search({
    shipment_id => $shipment->id,
    correspondence_templates_id => $CORRESPONDENCE_TEMPLATES__REMOVE_RETURN_ITEM
  })->count,
  '==',
  1,
  "Cancel Return Item email logged");


# Now create a new return, and send the cancel message cancelling all items in it

$return = Test::XTracker::Data->create_rma({
    items => $items
}, $pids);

#$return = Test::XTracker::Data->create_rma({
#    items => {
#        '48498-098' => { price => 250.00 },
#        '48499-097' => { price => 100.00 },
#    },
#});
$shipment = $return->shipment;
($payload, $header) = Test::XT::ActiveMQ::rma_cancel_message($return,
    [ { "sku" => $pids->[0]->{sku} },
      { "sku" => $pids->[1]->{sku} },
    ]
);

produces_return_note_ok( $return, sub {
    $amq->clear_destination($out_queue);
    $res = $amq->request(
        $app,
        $in_queue,
        $payload,
        $header,
    );
}, 'Return cancelled due to ARMA cancellation request from Website on ' . $payload->{returnCancelRequestDate},
'Cancelling all items' );

ok( $res->is_success, "Result from sending to /dc?-nap-returns queue, 'cancel_return_items' action" );

$amq->assert_messages({
    destination => $out_queue,
    assert_header => superhashof({
        type => 'OrderMessage',
    }),
    assert_body => superhashof({
        orderNumber => $shipment->order->order_nr,
        orderItems => bag(
            superhashof({
                sku => $pids->[0]->{sku},
                status => 'Dispatched',
            }),
            superhashof({
                sku => $pids->[1]->{sku},
                status => 'Dispatched',
            }),
        ),
    }),
    assert_count => 2, # Is this correct?? XT::Domain::Returns already
                       # sends updates, and ::Consumer::Returns *also*
                       # sends them!
}, 'order status sent on AMQ')
  or diag($res->content);

$return->discard_changes;
ok($return->is_cancelled, "Whole return has been cancelled");

cmp_ok(
  $schema->resultset('Public::ShipmentEmailLog')->search({
    shipment_id => $shipment->id,
    correspondence_templates_id => $CORRESPONDENCE_TEMPLATES__CANCEL_RETURN
  })->count,
  '==',
  1,
  "Cancel whole Return email logged");

done_testing;

sub produces_return_note_ok {
    my ( $return, $code, $note, $message ) = @_;

    subtest $message => sub {

        my $return_notes    = $schema->resultset('Public::ReturnNote');
        my $count_before    = $return_notes->count;

        diag 'Public::ReturnNote Records Before: ' . $count_before;

        # Call the code.
        $code->();

        my $count_after = $return_notes->count;
        diag 'Public::ReturnNote Records After: ' . $count_after;

        cmp_ok( $count_after, '==', $count_before + 1,
            'A return note has been created' );

        my $last_note = $return_notes
            ->search( undef, { order_by => { '-desc' => 'date' } } )
            ->first;

        cmp_deeply( { $last_note->get_columns }, {
            id              => ignore(),
            return_id       => $return->id,
            note            => $note,
            note_type_id    => $NOTE_TYPE__RETURNS,
            operator_id     => $APPLICATION_OPERATOR_ID,
            date            => ignore(),
        }, '.. and the note is correct' );

    };

}

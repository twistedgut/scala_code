#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use Catalyst::Utils qw/merge_hashes/;
use Storable qw/dclone/;

use XT::Domain::Returns;
use XTracker::Config::Local;
use XTracker::Constants::FromDB qw/
    :customer_issue_type
    :renumeration_type
/;

my $schema = Test::XTracker::Data->get_schema;
my $amq = Test::XTracker::MessageQueue->new;

ok(
  my $domain = XT::Domain::Returns->new(
    schema => $schema,
    msg_factory => $amq->producer,
  ),
  "Created Returns domain"
);

my $channel = Test::XTracker::Data->channel_for_business(name=>'nap');
my $pids = Test::XTracker::Data->find_or_create_products({
    how_many => 2,
    channel_id => $channel->id,
});
my $attrs = [
    { price => 100.00, _no_return => 1 },
    { price => 250.00 },
];

my $out_queue = config_var('Producer::PreOrder::TriggerWebsiteOrder','routes_map')->{$channel->web_name};

$amq->clear_destination($out_queue);

my ($return, $order, $si) = Test::XTracker::Data->make_rma({
    pids => $pids,
    attrs => $attrs,
});

$domain->add_items({
  return_id => $return->id,
  operator_id => 1,

  # This tests that the email gets created right, as we have STRICT mode one
  # for email tts
  send_default_email => 'yes',

  return_items => {
    $si->id => {
      type => 'Return',
      reason_id => $CUSTOMER_ISSUE_TYPE__7__INCORRECT_ITEM,
    }
  }
});

$return->discard_changes;

$amq->assert_messages({
    destination => $out_queue,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        orderNumber => $order->order_nr,
    }),
    assert_body => superhashof({
        orderItems => bag(
            superhashof({
                sku => $pids->[1]->{sku},
                returnReason => "PRICE",
                status => "Return Pending",
            }),
            superhashof({
                returnReason => "INCORRECT_ITEM",
                sku => $si->variant->sku,
                status => "Return Pending",
                xtLineItemId => $si->id,
            }),
        ),
        orderNumber            => $order->order_nr,
        rmaNumber              => $return->rma_number,
    }),
}, 'order status sent after add_items');


my $ri = $return->search_related('return_items',{
    shipment_item_id => { '!=' => $si->id },
})->slice(0,0)->single;

$amq->clear_destination($out_queue);

$domain->remove_items({
  return_id => $return->id,
  shipment_id => $return->shipment_id,
  operator_id => 1,

  # This tests that the email gets created right, as we have STRICT mode one
  # for email tts
  send_default_email => 'yes',

  return_items => {
    $ri->id => {
      remove => 1,
    }
  }
});

$amq->assert_messages({
    destination => $out_queue,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        orderNumber => $order->order_nr,
    }),
    assert_body => superhashof({
        orderItems => bag(
            all(
                superhashof({
                    sku => $pids->[1]->{sku},
                    status => "Dispatched",
                }),
                code(sub{! exists shift->{returnReason}}),
            ),
            superhashof({
                sku => $si->variant->sku,
                returnReason => "INCORRECT_ITEM",
                status => "Return Pending",
                xtLineItemId => $si->id,
            }),
        ),
    }),
}, 'order status sent after remove_items');

done_testing;

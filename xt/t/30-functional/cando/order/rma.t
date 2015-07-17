#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::NAP::Messaging::Helpers 'napdate';

use Test::XTracker::RunCondition export => ['$distribution_centre'];

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Constants::FromDB qw/
  :stock_process_status
  :authorisation_level
  :renumeration_status
  :shipment_item_status
/;

# go get some pids relevant to the db I'm using - channel is for test context
my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
});

foreach my $item (@{$pids}) {
    Test::XTracker::Data->ensure_variants_stock($item->{pid});
}





my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
    pids => $pids,
    attrs => [
        { price => 250.00 },
        { price => 100.00 },
    ],
});





my $order_nr = $order->order_nr;
ok(my $shipment = $order->shipments->first, "Sanity check: the order has a shipment");

# set the Customer's language to French just to make sure
# everything works ok when the Customer's locale is non-standard
$order->customer->set_language_preference('fr');

note "Order Nr: $order_nr";


Test::XTracker::Data->grant_permissions(
    'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );
Test::XTracker::Data->grant_permissions(
    'it.god', 'Goods In', 'Returns In', $AUTHORISATION_LEVEL__READ_ONLY);
Test::XTracker::Data->grant_permissions(
    'it.god', 'Goods In', 'Returns QC', $AUTHORISATION_LEVEL__READ_ONLY);
Test::XTracker::Data->grant_permissions(
    'it.god', 'Goods In', 'Putaway', $AUTHORISATION_LEVEL__READ_ONLY);
Test::XTracker::Data->set_department('it.god', 'Customer Care');

my $mech = Test::XTracker::Mechanize->new;
$mech->do_login;
$mech->force_datalite(1);

my $return;

$mech->order_nr($order_nr);

my $amq     = Test::XTracker::MessageQueue->new;
my $queue   = $mech->nap_order_update_queue_name();
$amq->clear_destination( $queue );
$mech->test_create_rma($shipment)
     ->test_refund_pending($return = $shipment->returns->first)
     ->test_add_rma_items($return)
     ->test_refund_amount($return, 350);

note("Return is $return");

$mech->test_remove_rma_items($return->return_items->not_cancelled->first)
     ->test_refund_amount($return, 100)
     ->test_bookin_rma($return, { test_send_email => 1 } );

# Currently the Bookin Process is only at in the handlers
# TODO: Move the bookin logic to the RMA domain, so we dont need to do this in a mech test

$return->discard_changes;
my $ri = $return->return_items->not_cancelled->first;

$amq->assert_messages({
    destination => $queue,
    filter_body => superhashof({
        orderItems => superbagof(superhashof({
            status => 'Return Received',
        })),
    }),
    assert_header => superhashof({
        type => 'OrderMessage',
    }),
    assert_body => superhashof({
        '@type' => 'order',
        orderNumber => $order_nr,
        rmaNumber =>$return->rma_number,
        returnExpiryDate => napdate($return->expiry_date),
        returnCreationDate => napdate($return->creation_date),
        returnCancellationDate => napdate($return->cancellation_date),
        orderItems => superbagof(superhashof({
            xtLineItemId => $ri->shipment_item_id,
            status => 'Return Received',
            returnReason => 'PRICE',
            returnCreationDate => napdate($ri->creation_date),
        })),
    }),
}, 'RMA message for bookin message sent');
$amq->clear_destination( $queue );

$mech->test_returns_qc_pass($return)
     ->test_refund_complete($return);

# Still not 'Returned' until we process the refund
$amq->assert_messages({
    destination => $queue,
    filter_body => superhashof({
        orderItems => superbagof(superhashof({
            status => 'Returned',
        })),
    }),
    assert_header => superhashof({
        type => 'OrderMessage',
    }),
    assert_body => superhashof({
        '@type' => 'order',
        orderNumber => $order_nr,
        orderItems => superbagof(superhashof({
            xtLineItemId => $ri->shipment_item_id,
            status => 'Returned',
            returnCompletedDate => napdate($ri->refund_date),
        })),
    }),
}, 'RMA message sent for returned item (refund not yet processed)');
$amq->clear_destination( $queue );

# Resetting renumerations so we can test completing it through the Active Invoices page too.
my $renum = $return->renumerations->not_cancelled->first;
$renum->update( {
    sent_to_psp             => 0,
    renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
} );
$renum->renumeration_status_logs->search( { renumeration_status_id => $RENUMERATION_STATUS__COMPLETED } )->delete;

$mech->release_refund_ok($return, { check_cancel_rma => 1 } );

$amq->assert_messages({
    destination => $queue,
    filter_body => superhashof({
        orderItems => superbagof(superhashof({
            status => 'Returned',
        })),
    }),
    assert_header => superhashof({
        type => 'OrderMessage',
    }),
    assert_body => superhashof({
        '@type' => 'order',
        orderNumber => $order_nr,
        orderItems => superbagof(superhashof({
            xtLineItemId => $ri->shipment_item_id,
            status => 'Returned',
            returnCompletedDate => napdate($ri->refund_date),
        })),
    }),
}, 'RMA message sent for returned item (refund now processed)');
$amq->clear_destination( $queue );

done_testing;
# Perhaps the rest of this should be a seperate test file (t/order/rma_exchange.t)

# TODO: Things left to test
#   * When removing an item from an rma that it releases {exchange,paymnets}
#   * Test mixed exchange/refund orders better, particularly to do with the
#     status of shipments/refund invoices






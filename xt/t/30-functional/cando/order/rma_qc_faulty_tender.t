#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::NAP::Messaging::Helpers 'atleast';
use XTracker::Constants::FromDB qw/
  :stock_process_status
  :authorisation_level
/;

Test::XTracker::Data->grant_permissions(
    'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );
Test::XTracker::Data->grant_permissions(
    'it.god', 'Goods In', 'Returns In', $AUTHORISATION_LEVEL__OPERATOR);
Test::XTracker::Data->grant_permissions(
    'it.god', 'Goods In', 'Returns QC', $AUTHORISATION_LEVEL__OPERATOR);
Test::XTracker::Data->grant_permissions(
    'it.god', 'Goods In', 'Returns Faulty', $AUTHORISATION_LEVEL__OPERATOR);

Test::XTracker::Data->set_department('it.god', 'Customer Care');

my $amq   = Test::XTracker::MessageQueue->new;
my $mech  = Test::XTracker::Mechanize->new;
$mech->do_login;
$mech->force_datalite(1);

for my $ch (qw(nap out mrp)) {

    # go get some pids relevant to the db I'm using - channel is for test context
    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
        channel => $ch,
    });

    my $queue = $mech->nap_order_update_queue_name( $channel );

    my $pc = $pids->[0]{product_channel};
    $pids->[0]{product}->product_channel->update( { live => 0, visible => 0 } );
    $pc->update( { live => 1, visible => 1 } );

    foreach my $item (@{$pids}) {
        Test::XTracker::Data->ensure_variants_stock($item->{pid});
    }

    my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => {
            customer_id => Test::XTracker::Data->find_or_create_customer({channel_id => $channel->id})->id,
            channel_id => $channel->id,
        },
        attrs => [
            { price => 100.00 },
        ],
    });

    my $order_nr = $order->order_nr;
    ok(my $shipment = $order->shipments->first, "Sanity check: the order has a shipment");

    note "Order Nr: $order_nr, Channel : $ch";

    my $return;

    $mech->order_nr($order_nr);

    note 'Order Created - tender value = '.$order->tenders->first->value;

    $mech->test_create_rma($shipment,0,'Defective/faulty')
         ->test_bookin_rma($return = $shipment->returns->first);

    my $renum = $return->renumerations->first;
    my $old_tender_val = $renum->renumeration_tenders->first->value || 0;
    my $renum_item = $renum->renumeration_items->first;
    my $item_price = $renum_item->unit_price + $renum_item->tax + $renum_item->duty;

    note 'RMA Created - renumeration tender value = '.$renum->renumeration_tenders->first->value;

    $amq->clear_destination( $queue );

    $mech->test_returns_qc_faulty($return)
         ->test_refund_complete($return);

    my $ri = $return->return_items->not_cancelled->first;

    $amq->assert_messages({
        destination => $queue,
        filter_body => superhashof({
            orderNumber => $order_nr,
            orderItems => bag(superhashof({
                xtLineItemId => $ri->shipment_item_id,
            })),
        }),
        assert_header => superhashof({
            type => 'OrderMessage',
        }),
        assert_body => superhashof({
            '@type' => 'order',
            orderNumber => $order_nr,
            orderItems => bag(superhashof({
                xtLineItemId => $ri->shipment_item_id,
                status => 'Return Received',
            })),
        }),
        assert_count => atleast(1),
    }, 'RMA message sent for faulty item (refund now processed)');

    my $new_tender_val = $renum->renumeration_tenders->first->value || 0;

    note "Item Price - $item_price";
    note 'Shipping Cost - '. $renum->shipping;

    note "Return QC rejected - new renumeration tender value = $new_tender_val";

    cmp_ok($new_tender_val, '==', ( $old_tender_val - $item_price ), "New tender value after RMA rejected less than item price");

    $return->discard_changes;
}

done_testing;

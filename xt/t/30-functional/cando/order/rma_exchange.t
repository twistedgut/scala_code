#!/usr/bin/env perl
use NAP::policy qw/test/;
use Test::NAP::Messaging::Helpers 'atleast','napdate';

use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw(
                                :authorisation_level
                                :renumeration_type
                                :renumeration_class
                                :renumeration_status
                                :shipment_type
                            );

use Test::XTracker::RunCondition dc => 'DC1', prl_phase => 0, export => qw( $iws_rollout_phase );

my $amq = Test::XTracker::MessageQueue->new;

# We need an rma to test with exchange instead of returns.
# go get some pids relevant to the db I'm using - channel is for test context
#my ($channel,$pids) = Test::XTracker::Data->grab_products({
#    how_many => 2,
#});
my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
    how_many_variants => 2,
    ensure_stock_all_variants => 1,
});

my $order_hash;
my $exchange_order;
my $exchange_charges_order;

my $data_helper = Test::XTracker::Data->new;

# create an Order which will be domestic
($exchange_order, $order_hash)  = Test::XTracker::Data->create_db_order({
    pids => $pids,
    attrs => [
        { price => 100.00, tax => 5, duty => 0, },
        { price => 250.00, tax => 5, duty => 0, },
    ],
    base => {
        invoice_address_id => $data_helper->create_order_address_in('UK')->id,
        shipping_account_id => Test::XTracker::Data->find_shipping_account({
            channel_id  => $channel->id,
            acc_name    => 'Domestic'
        })->id()
    },
});

# create an Order which will be International and should incurr Exchange Charges
($exchange_charges_order, $order_hash)  = Test::XTracker::Data->create_db_order({
    pids => $pids,
    attrs => [
        { price => 100.00, tax => 5, duty => 10, },
        { price => 250.00, tax => 5, duty => 10, },
    ],
    base => {
        shipment_type => $SHIPMENT_TYPE__INTERNATIONAL,
        invoice_address_id => $data_helper->create_order_address_in('IntlWorld')->id,
        shipping_account_id => Test::XTracker::Data->find_shipping_account({
            channel_id  => $channel->id,
            acc_name    => 'International'
        })->id()
    },
});


my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::Fulfilment',
    ],
);

$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Order Search',
        'Goods In/Returns In',
        'Goods In/Returns QC',
        'Goods In/Putaway',
        'Fulfilment/Selection',
        'Fulfilment/Picking',
        'Fulfilment/Packing',
        'Fulfilment/Airwaybill',
        'Fulfilment/Dispatch',
    ]},
    dept => 'Customer Care'
});

my $mech = $framework->mech;
$mech->force_datalite(1);

note "TEST Exchange which should have Charges";
$mech->order_nr( $exchange_charges_order->order_nr );
ok(my $shipment = $exchange_charges_order->shipments->first, "Sanity check: the order has a shipment");
$mech->test_create_rma( $shipment, 'exchange' );
my $return  = $shipment->discard_changes->returns->first;
my $renum   = $return->renumerations->first;
cmp_ok( $renum->total_value, '==', ( 5 + 10 ), "Return Renumeration Total is Tax + Duty" );
cmp_ok( $renum->renumeration_class_id, '==', $RENUMERATION_CLASS__RETURN, "Return Renumeration is of Class 'Return'" );
cmp_ok( $renum->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_DEBIT, "Return Renumeration Type is 'Card Debit'" );
cmp_ok( $renum->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_AUTHORISATION, "Return Renumeration Status is 'Awaiting Authorisation'" );

my $queue = $mech->nap_order_update_queue_name();

note "TEST Exchange which shouldn't have Charges Applied";
$amq->clear_destination( $queue );
my $order_nr = $exchange_order->order_nr;
$mech->order_nr( $order_nr );
ok($shipment = $exchange_order->shipments->first, "Sanity check: the order has a shipment");
$mech->test_create_rma($shipment, 'exchange');
$return = $shipment->discard_changes->returns->first;
my $return_item = $return->return_items->not_cancelled->first;
ok( !defined $return->renumerations->first, "Exchange has no Renumeration as there were no Refunds or Charges" );

$mech->test_exchange_pending($return)
     ->test_add_rma_items($return, 'exchange')
     ->test_exchange_item_added($return)
     ->test_remove_rma_items($return_item)
     ->test_exchange_item_removed($return)
     ->test_exchange_item_added($return)
     ->test_bookin_rma($return);

my $ri = $return->return_items->not_cancelled->first;

$amq->assert_messages({
    destination => $queue,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        '@type' => 'order',
        orderNumber => $order_nr,
        orderItems => superbagof(superhashof({
            xtLineItemId => $ri->shipment_item_id,
            status => 'Return Received',
        })),
    }),
    assert_count => atleast(1),
}, 'RMA message for bookin message sent');

$amq->clear_destination( $queue );

$mech->test_returns_qc_pass($return)
     ->test_exchange_released($return);

# Still not 'Returned' until we ship the exchange
$amq->assert_messages({
    destination => $queue,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        '@type' => 'order',
        orderNumber => $order_nr,
        orderItems => superbagof(superhashof({
            xtLineItemId => $ri->shipment_item_id,
            status => 'Return Received',
        })),
    }),
    assert_count => atleast(1),
}, 'RMA message sent for returned item (exchange not yet shipped)');


my $exch_ship_nr = $return->exchange_shipment_id;

my $schema = $return->result_source->schema;

note "Exchange shipment id is $exch_ship_nr";
my $skus;
if ($iws_rollout_phase == 0) {
    my $print_directory = Test::XTracker::PrintDocs->new();
    $mech->test_direct_select_shipment($exch_ship_nr);
    # Get the location from the picking list

    # TODO: This only works since the create DB order is missing a picking list. If
    # that every changes, this will start failing as it will likely pick up the
    # wrong picking list
    $skus = $mech->get_info_from_picklist( $print_directory,
      { $ri->exchange_shipment_item->variant->sku => {} }
    );
} else {
    # This is considerably faster than combing through the list of all the shipments to be selected.
    $framework->flow_mech__fulfilment__selection
        ->flow_mech__fulfilment__selection_submit($exch_ship_nr);

    # Get the new sku
    $skus = { $ri->exchange_shipment_item->variant->sku => {} };
}

$amq->clear_destination( $queue );

$mech->test_pick_shipment($exch_ship_nr, $skus);
$mech->force_datalite(0);
$mech->test_pack_shipment($exch_ship_nr, $skus);
$mech->test_assign_airway_bill($exch_ship_nr);
$mech->test_dispatch($exch_ship_nr);

$amq->assert_messages({
    destination => $queue,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        '@type' => 'order',
        orderNumber => $order_nr,
        orderItems => superbagof(superhashof({
            xtLineItemId => $ri->shipment_item_id,
              status => 'Returned',
              returnCompletedDate => napdate($ri->exchange_shipment_item->shipment->dispatched_date),
        })),
    }),
    assert_count => atleast(1),
}, 'RMA message sent for returned item (exchange not yet shipped)');

done_testing;

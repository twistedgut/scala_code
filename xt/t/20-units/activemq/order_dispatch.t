#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local qw/config_var instance rma_cutoff_days_for_email_copy_only/;
use Test::NAP::Messaging::Helpers 'napdate';
use XTracker::Constants::FromDB qw/
  :return_status
  :return_item_status
  :shipment_item_status
  :shipment_type
/;

my $amq         = Test::XTracker::MessageQueue->new;
my $queue_name  = "/queue/nap-".lc( instance() )."-orders";

# go get some pids relevant to the db I'm using - channel is for test context
my $po = Test::XTracker::Data->create_test_products({how_many=>2});

my ($channel,$all_pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
    phys_vouchers => {
        how_many => 1,
    },
    virt_vouchers => {
        how_many => 1,
    },
});
$all_pids->[2]{assign_code_to_ship_item}    = 1;
$all_pids->[3]{assign_code_to_ship_item}    = 1;

# sort the PIDS
my $pids;
$pids   = [ grep { !$_->{ voucher } } sort { $a->{pid} <=> $b->{pid} } @{ $all_pids } ];

my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
    pids => $pids,
    attrs => [
        { price => 100.00 },
        { price => 250.00 },
    ],
});
# set shipment items PWS OL ID field to NULL for purposes of test
my $ship_items  = $order->shipments->first->shipment_items->order_by_sku;
while ( my $item = $ship_items->next ) {
    $item->update( { pws_ol_id => undef } );
}


my $order_nr = $order->order_nr;
my $schema = Test::XTracker::Data->get_schema;
my $mesg_type = 'XT::DC::Messaging::Producer::Orders::Update';

ok(my $shipment = $order->shipments->first, "Sanity check: the order has a shipment");

note "Testing Return Cutoff Date for Shipment";
my $cut_off_date    = $shipment->dispatched_date->clone->truncate( to => 'day' );
$cut_off_date->add( days => $shipment->shipping_account->return_cutoff_days, hours => 23, minutes => 59, seconds => 59 );
cmp_ok( DateTime->compare( $shipment->return_cutoff_date, $cut_off_date ), '==', 0,
                                "Shipment Return Cutoff Date is as expected: ".$cut_off_date );
# check that the cutoff date is at least the same that would be mentioned in the Late RMA Email
my $diff            = $shipment->return_cutoff_date->subtract_datetime( $shipment->dispatched_date );
my $min_cutoff_days = rma_cutoff_days_for_email_copy_only( $channel );

my $min_cutoff=$shipment->dispatched_date->clone->add(days=>$min_cutoff_days);
ok(
    $cut_off_date->compare($min_cutoff)>0,
      'cut off date ('
    . $cut_off_date
    . ') is later than the minimum cut-off date; '
    . $min_cutoff_days
    . ' days or more after '
    . $shipment->dispatched_date
);

note "TESTING Regular Dispatch";
note "Order Nr. ".$order->order_nr.", Shipment Id: ".$shipment->id;
$amq->clear_destination( $queue_name );
lives_ok {
    $amq->transform_and_send(
        $mesg_type,
        {
            schema      => $schema,
            order_id    => $order->id,
        },
    );
} "Can send valid message";

my @items = $shipment->shipment_items->order_by_sku;
$amq->assert_messages({
    destination => $queue_name,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        orderNumber => $order->order_nr,
    }),
    assert_body => superhashof({
        orderItems => [
            superhashof({
                sku => $pids->[0]->{sku},
                unitPrice => "100.000",
                duty => "0.000",
                status => "Dispatched",
                tax => "0.000",
            }),
            superhashof({
                sku => $pids->[1]->{sku},
                unitPrice => "250.000",
                duty => "0.000",
                status => "Dispatched",
                tax => "0.000",
            }),
        ],
        returnCutoffDate => napdate($shipment->return_cutoff_date),
        status           => "Dispatched",
    }),
}, 'order status sent on AMQ' );

# Change
$order->get_standard_class_shipment->update({
  shipment_type_id => $SHIPMENT_TYPE__PREMIER
});

$amq->clear_destination( $queue_name );
lives_ok {
    $amq->transform_and_send(
        $mesg_type,
        {
            schema      => $schema,
            order_id    => $order->id,
        },
    );
} "Can send valid message";


$amq->assert_messages({
    destination => $queue_name,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        orderNumber => $order->order_nr,
    }),
    assert_body => superhashof({
        shippingMethod => "Premier",
    }),
}, 'order status sent on AMQ for premier order' );


note "TESTING PWS OL ID's";
# update all the PWS OL ID's on the shipment item records
my $pws_ol_id   = 543160;       # just pick a number
my @pws_ol_ids;
$ship_items->reset();
while ( my $item = $ship_items->next ) {
    $item->update( { pws_ol_id => ++$pws_ol_id } );
    push @pws_ol_ids, $pws_ol_id;      # store the id for comparison later
}

# send the message
$amq->clear_destination( $queue_name );
lives_ok {
    $amq->transform_and_send(
        $mesg_type,
        {
            schema      => $schema,
            order_id    => $order->id,
        },
    );
} "Can send valid message";

# check message sent ok
$amq->assert_messages({
    destination => $queue_name,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        orderNumber => $order->order_nr,
    }),
    assert_body => superhashof({
        orderItems => [
            superhashof({
                sku => $pids->[0]->{sku},
                orderItemNumber => $pws_ol_ids[0],
            }),
            superhashof({
                sku => $pids->[1]->{sku},
                orderItemNumber => $pws_ol_ids[1],
            }),
        ],
    }),
}, 'PWS OL ID sent on AMQ for each shipment item' );


#
# Create some voucher order's and check the voucher code's
# go across with the voucher order items.
#
note "TESTING Orders with Voucher Codes";

# try voucher only order
note "Vouchers only Order";
($order, $order_hash) = Test::XTracker::Data->create_db_order({
    pids => [ $all_pids->[2], $all_pids->[3] ],
});
ok($shipment = $order->shipments->first, "Sanity check: the order has a shipment");
note "Order Nr. ".$order->order_nr.", Shipment Id: ".$shipment->id;

# set shipment items PWS OL ID field to a value
my @ship_items  = $order->shipments->first->shipment_items->order_by_sku->all;
foreach my $item ( @ship_items ) {
    $item->update( { pws_ol_id => ++$pws_ol_id } );
}

# send the message
$amq->clear_destination( $queue_name );
lives_ok {
    $amq->transform_and_send(
        $mesg_type,
        {
            schema      => $schema,
            order_id    => $order->id,
        },
    );
} "Can send valid message";

# check message sent ok
$amq->assert_messages({
    destination => $queue_name,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        orderNumber => $order->order_nr,
    }),
    assert_body => superhashof({
        orderItems => [
            superhashof({
                sku             => $all_pids->[2]{sku},
                orderItemNumber => $ship_items[0]->pws_ol_id,
                voucherCode     => $ship_items[0]->voucher_code->code,
            }),
            superhashof({
                sku             => $all_pids->[3]{sku},
                orderItemNumber => $ship_items[1]->pws_ol_id,
                voucherCode     => $ship_items[1]->voucher_code->code,
            }),
        ],
    }),
}, 'Voucher only Order sent with Voucher Codes' );

# try mixed order
note "Normal Products & Vouchers Order";
($order, $order_hash) = Test::XTracker::Data->create_db_order({
    pids => [ @{ $pids }, $all_pids->[2], $all_pids->[3] ],
});
ok($shipment = $order->shipments->first, "Sanity check: the order has a shipment");
note "Order Nr. ".$order->order_nr.", Shipment Id: ".$shipment->id;
# set shipment items PWS OL ID field to a value
@ship_items = $order->shipments->first->shipment_items->order_by_sku->all;
foreach my $item ( @ship_items ) {
    $item->update( { pws_ol_id => ++$pws_ol_id } );
}

# send the message
$amq->clear_destination( $queue_name );
lives_ok {
    $amq->transform_and_send(
        $mesg_type,
        {
            schema      => $schema,
            order_id    => $order->id,
        },
    );
} "Can send valid message";

# check message sent ok
$amq->assert_messages({
    destination => $queue_name,
    filter_header => superhashof({
        type => 'OrderMessage',
    }),
    filter_body => superhashof({
        orderNumber => $order->order_nr,
    }),
    assert_body => superhashof({
        orderItems => [
            superhashof({
                sku             => $pids->[0]{sku},
                orderItemNumber => $ship_items[0]->pws_ol_id,
            }),
            superhashof({
                sku             => $pids->[1]{sku},
                orderItemNumber => $ship_items[1]->pws_ol_id,
            }),
            superhashof({
                sku             => $all_pids->[2]{sku},
                orderItemNumber => $ship_items[2]->pws_ol_id,
                voucherCode     => $ship_items[2]->voucher_code->code,
            }),
            superhashof({
                sku             => $all_pids->[3]{sku},
                orderItemNumber => $ship_items[3]->pws_ol_id,
                voucherCode     => $ship_items[3]->voucher_code->code,
            }),
        ],
    }),
}, 'Normal Products & Voucher Order sent with Voucher Codes (for the Voucher items only)' );

done_testing();

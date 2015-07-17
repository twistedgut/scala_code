#!/usr/bin/env perl

use strict;
use warnings;

use FindBin::libs;
use Test::XTracker::Data;
use Test::Most;

use base 'Test::Class';

# Check various components of the customer care order view page

use Moose qw|has|;
use XTracker::Config::Local qw|:DEFAULT|;
use XTracker::Database::Shipment qw|
    :DEFAULT
    get_order_shipment_info
    get_shipment_item_voucher_usage
|;

has order => (is => 'rw', isa => 'XTracker::Schema::Result::Public::Orders');
has schema => (is => 'rw', isa => 'XTracker::Schema', handles=>[qw|resultset|]);
has dbh => (is => 'rw', isa => 'Object');

sub startup : Tests(startup => 1) {
    my $test = shift;
    use_ok 'XTracker::Order::Functions::Order::OrderView';

    $test->schema(
        Test::XTracker::Data->get_schema
    );

    $test->dbh(
        Test::XTracker::Data->get_dbh
    );
}

# check it returns vouchers
sub test_get_order_shipment_item_info : Tests {
    my $test = shift;
    $test->order(
        $test->setup_order
    );

    my $s = get_order_shipment_info($test->dbh, $test->order->id);
    my ($shipment_id) = keys %$s;
    ok($shipment_id, 'get shipment info for order with voucher');

    my $sinfo = get_shipment_item_info($test->dbh, $shipment_id);
    my ($sid) = keys %$sinfo;
    ok($sid, 'can get shipment item info for voucher');

    is($sinfo->{$sid}{voucher}, 1, 'shipment item marked as voucher');
}

sub test_get_voucher_used_on_order : Tests {
    my $test = shift;
    my $code = time;
    my $voucher = Test::XTracker::Data->create_voucher({value=>200});
    my $vi = $voucher->add_code($code);
    my ($order) = $test->setup_order(
        [{ type => 'voucher_credit', value => 100, voucher_code_id => $vi->id}],
        );

    ok(defined $order);

    is($order->voucher_value_used($vi->id), '100.000', 'looked up voucher usage');
}

sub test_get_shipped_used_vouchers : Tests {
    my $test = shift;
    # get shipment into
    my $sinfo = get_shipment_item_info($test->dbh,
        $test->order->shipments->first->id);
    my ($sid) = keys %$sinfo;

    # create order using purchased voucher
    my $vcid = $test->schema->resultset('Public::ShipmentItem')
        ->find($sid)->voucher_code->id;
    ok($vcid);

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
        });

    my ($v_order) = $test->setup_order(
        [{ type => 'voucher_credit', value => 100, voucher_code_id => $vcid}],
        { $pids->[0]{sku} => { price => 100, tax => 0, duty => 0} },
        -1
    );

    ok(defined $v_order, 'order defined');

    # get voucher usage
    my @order = get_shipment_item_voucher_usage($test->schema, $sid);

    diag "found ".scalar(@order)." orders using the vouchers";

    ok(scalar(@order), "found order");

    diag "check ". $test->order->id;
}

sub setup_order {
    my ($test, $tenders, $items, $sku_info) = @_;

    $tenders ||= [
    { type => 'card_debit', value => 200 },
    { type => 'store_credit', value => 200 },
    ];

    my $voucher = Test::XTracker::Data->create_voucher({value => 400.00});

    $items ||= {
        $voucher->variant->sku => {
            price => 400.00, tax => 0, duty => 0, voucher => 1
        }
    };

    $sku_info  ||=  {
        $voucher->variant->sku => {
            voucher => 1, product => $voucher, variant => $voucher->variant,
            assign_code_to_ship_item => 1,
        }
    };

    my $channel = $voucher->channel;

    my $p = {
        tenders => $tenders,
        channel_id => $channel->id,
        shipping_account_id => $channel->shipping_accounts->first->id,
        items => $items,
    };

    $p->{sku_info}  = $sku_info
        if $sku_info != -1;

    my ($order) = Test::XTracker::Data->do_create_db_order($p);
}

Test::Class->runtests;

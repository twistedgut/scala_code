#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::LoadTestConfig;

use base 'Test::Class';

use XT::DC::Messaging::Producer::PurchaseOrder;
use Test::XTracker::MessageQueue;
use Test::XTracker::Data;

use XTracker::Constants::FromDB qw{:purchase_order_status};

sub startup : Test(startup) {
    my $test = shift;
    $test->{sender} = Test::XTracker::MessageQueue->new;
}

sub setup : Test(setup) {
    my $test = shift;
    $test->{sender}->clear_destination($test->po_queue_name);
}

sub create_vpo {
    return Test::XTracker::Data->create_voucher_purchase_order({
        status_id => $_[1],
    });
}

sub po_queue_name {
    return '/queue/fulcrum/purchase_order';
}

sub test_voucher_po_part_delivered : Tests {
    my $test = shift;
    my $po = $test->create_vpo( $PURCHASE_ORDER_STATUS__PART_DELIVERED );
    $test->{sender}->transform_and_send(
        'XT::DC::Messaging::Producer::PurchaseOrder', $po
    );
    $test->{sender}->assert_messages({
        destination => $test->po_queue_name,
        assert_header => superhashof({
            type => 'update_status',
        }),
        assert_body => superhashof({
            purchase_order_number  => $po->purchase_order_number,
            status                 => 'Part Delivered',
        }),
    }, 'purchase order status part delivered ok');
}

sub test_voucher_po_delivered : Tests {
    my $test = shift;
    my $po = $test->create_vpo( $PURCHASE_ORDER_STATUS__DELIVERED );
    $test->{sender}->transform_and_send(
        'XT::DC::Messaging::Producer::PurchaseOrder', $po
    );
    $test->{sender}->assert_messages({
        destination => $test->po_queue_name,
        assert_header => superhashof({
            type => 'update_status',
        }),
        assert_body => superhashof({
            purchase_order_number  => $po->purchase_order_number,
            status                 => 'Delivered',
        }),
    }, 'purchase order status delivered ok');
}

sub test_voucher_po_on_order_death : Tests {
    my $test = shift;
    my $po = $test->create_vpo( $PURCHASE_ORDER_STATUS__ON_ORDER );
    throws_ok {
        $test->{sender}->transform_and_send(
            'XT::DC::Messaging::Producer::PurchaseOrder', $po
        );
    } qr{must have a status of 'Delivered' or 'Part Delivered'},
    q{purchase order only accepts 'Delivered' or 'Part Delivered' POs};
}

Test::Class->runtests;

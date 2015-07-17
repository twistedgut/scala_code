#!/usr/bin/env perl

use strict;
use warnings;

use FindBin::libs;

use Test::XTracker::Data;
use Test::Most;
use XTracker::Constants::FromDB qw(:channel);

use base 'Test::Class';

my $schema;
sub startup : Test(startup => 1) {
    use_ok 'XTracker::Schema::Result::Public::SuperPurchaseOrder';
    ok($schema = Test::XTracker::Data->get_schema);
}

sub test_search_children : Tests {

    # setup a voucher purchase order
    ok(my $voucher = Test::XTracker::Data->create_voucher);
    my $vpo = Test::XTracker::Data->setup_purchase_order($voucher->id);
    isa_ok( $vpo, 'XTracker::Schema::Result::Voucher::PurchaseOrder', 'check type' );

    # setup a public purchase order
    ok(my $p = Test::XTracker::Data->grab_products({
        how_many => 1,
        channel_id=> Test::XTracker::Data->channel_for_nap()->id
    } ));
    ok(my $product = $schema->resultset('Public::Product')->find($p->[0]->{pid}));
    my $po = Test::XTracker::Data->setup_purchase_order($product->id);
    isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder', 'check type' );

    # checks results are inflated correctly
    my @po = $schema->resultset('Public::SuperPurchaseOrder')->search({
            designer_id=>$po->designer_id
        });

    isa_ok($_, 'XTracker::Schema::Result::Public::PurchaseOrder') for @po;

    @po = $schema->resultset('Public::SuperPurchaseOrder')->find({id=>$po->id});
    for (@po) {
        isa_ok($_, 'XTracker::Schema::Result::Public::PurchaseOrder') ;
        ok($_->designer, "designer rel works");
        lives_and {
            $_->stock_orders;
            $_->quantity_ordered;
            $_->originally_ordered;
            $_->quantity_delivered;
        } "stock_orders rel and subs works";
    }

    @po = $schema->resultset('Public::SuperPurchaseOrder')->find({id=>$vpo->id});
    for (@po) {
        isa_ok($_, 'XTracker::Schema::Result::Voucher::PurchaseOrder');
        lives_ok {
            $_->stock_orders;
            $_->quantity_ordered;
            $_->originally_ordered;
            $_->quantity_delivered;
        } "stock_orders rel and subs works";
    }
}

sub test_update_not_editable_in_fulcrum : Tests {

    my ($channel, $pids) = Test::XTracker::Data->grab_products({
        how_many     => 1,
        channel_id   => Test::XTracker::Data->channel_for_nap()->id,
        force_create => 1,
    });

    my $product = $pids->[0]->{product_channel}->product;
    my $po = $product->stock_order->first->purchase_order;

    ok( !$po->update_not_editable_in_fulcrum('any_po_number'), 'PO editable in Fulcrum');
    $po->enable_edit_po_in_xt;

    my $new_po_number = 'test_po_number_'.Data::UUID->new->create_str;
    ok( $po->update_not_editable_in_fulcrum($new_po_number), 'PO NOT editable in Fulcrum');

    is (
        $schema->resultset('Public::PurchaseOrderNotEditableInFulcrum')->search({ number => $new_po_number })->count,
        1,
        'PO updated in PurchaseOrderNotEditableInFulcrum'
    );

}

sub test_update : Tests {

    my ($channel, $pids) = Test::XTracker::Data->grab_products({
        how_many     => 1,
        channel_id   => Test::XTracker::Data->channel_for_nap()->id,
        force_create => 1,
    });

    my $product = $pids->[0]->{product_channel}->product;
    my $po = $product->stock_order->first->purchase_order;

    $po->enable_edit_po_in_xt;

    # Update description
    my $new_description = 'test_description_'.Data::UUID->new->create_str;

    $po->update({ description => $new_description, });

    my $expected_po = $schema->resultset('Public::PurchaseOrder')->find({ id => $po->id }, {result_class => 'DBIx::Class::ResultClass::HashRefInflator',});
    $expected_po->{description}             = $new_description;

    my $got_po = $schema->resultset('Public::PurchaseOrder')->find({ id => $po->id }, {result_class => 'DBIx::Class::ResultClass::HashRefInflator',});

    is($got_po->{description}, $expected_po->{description}, 'updated PO - description');

    # Update PO
    my $new_po_number   = 'test_po_number_'.Data::UUID->new->create_str;
    $po->update({ purchase_order_number => $new_po_number });
    $expected_po->{purchase_order_number}   = $new_po_number;

    $got_po = $schema->resultset('Public::PurchaseOrder')->find({ id => $po->id }, {result_class => 'DBIx::Class::ResultClass::HashRefInflator',});

    is($got_po->{purchase_order_number}, $expected_po->{purchase_order_number}, 'updated PO - PO number');

    is (
        $schema->resultset('Public::PurchaseOrderNotEditableInFulcrum')->search({ number => $new_po_number })->count,
        1,
        'PO updated in PurchaseOrderNotEditableInFulcrum via update'
    );

    # Do not update already existing PO
    ok(!$po->update({ purchase_order_number => $new_po_number }), 'Do not update already existing PO');
}

Test::Class->runtests;

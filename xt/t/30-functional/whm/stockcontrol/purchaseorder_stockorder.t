#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

purchaseorder_stockorder.t - Test the Purchase Order page

=head1 DESCRIPTION

Create a product with one purchase order, ensure the Purchase Order Overview
page displays one purchase order.

Create a product with three purchase orders, ensure the Purchase Order Overview
page displays three purchase orders.

#TAGS xpath inventory purchaseorder whm

=cut

use Test::XTracker::Data;
use Test::XTracker::Mechanize;

use Data::Dump 'pp';

my $mech = Test::XTracker::Mechanize->new;
Test::XTracker::Data->set_department('it.god', 'Finance');
Test::XTracker::Data->grant_permissions ('it.god', 'Stock Control', 'Purchase Order', 3);

$mech->do_login;


my $schema = Test::XTracker::Data->get_schema();
my $channel = Test::XTracker::Data->get_local_channel();
my $purchase_order = Test::XTracker::Data->create_from_hash({
    placed_by       => 'po test',
    stock_order     => [ my $stock_order_args = {
        product         => {
            style_number        => 'po style',
            variant             => [{
                size_id             => 1,
                stock_order_item    => {
                    quantity            => 1,
                },
            }],
            product_channel     => [{
                channel_id          => $channel->id,
            }],
            price_purchase      => {},
        },
    }],
});

my ($product) = $purchase_order->stock_orders
    ->related_resultset('stock_order_items')
    ->related_resultset('variant')
    ->related_resultset('product')
    ->all;

## Test for products with one PO
{
    my $row = $product->stock_order->single;

    $mech->get_ok('/StockControl/PurchaseOrder/StockOrder?so_id=' . $row->id );
    note '/StockControl/PurchaseOrder/StockOrder?so_id=' . $row->id;
    my $po_links = $mech->find_xpath(
        "//td/a[\@href=~'/StockControl/PurchaseOrder/Overview']"
    );
    is($po_links->size, 1, 'Product with one purchase order, displays one purchase order.' );
}

for (1..2) {
    my $new_po=Test::XTracker::Data->create_purchase_order();
    my $new_so=Test::XTracker::Data->create_stock_order({
        purchase_order_id => $new_po->id,
        product_id => $product->id,
        %$stock_order_args,
    });
}

## Test for products with three POs
{
    my $row = $product->stock_order->first;

    $mech->get_ok('/StockControl/PurchaseOrder/StockOrder?so_id=' . $row->id );
    my $po_links = $mech->find_xpath(
        "//td/a[\@href =~ '/StockControl/PurchaseOrder/Overview']"
    );
    is($po_links->size, 3, 'Product with three purchase orders, displays three purchase orders');
}
done_testing;

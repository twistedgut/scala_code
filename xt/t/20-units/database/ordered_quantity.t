#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::Data;
use XTracker::Constants::FromDB qw($STOCK_ORDER_ITEM_STATUS__DELIVERED);

my $schema=Test::XTracker::Data->get_schema;

# Create a product
my (undef,$pids)=Test::XTracker::Data->grab_products({force_create=>1});
my $product=$pids->[0]{product};
my $product_id=$pids->[0]{product}->id;
my $variant_id = $pids->[0]{variant_id};

my $got = $product->get_ordered_item_quantity_details;

# Create comparison data structure (40 is the default quantity in the test method)
my $expected = {
    $variant_id => {
        1 => {
            delivered_quantity => 0,
            on_order_quantity => 40,
            total_ordered_quantity => 40,
        },
    },
    $variant_id + 1 => ignore(),
};

cmp_deeply($got,$expected,'Quantities are as expected') or diag explain $got;

# Confirm the original stock
my @stock_orders = $product->stock_order->all;
foreach my $stock_order ( @stock_orders ) {
    my @stock_order_items = $stock_order->stock_order_items;
        foreach my $soi ( @stock_order_items ) {
            $soi->update({
                status_id => $STOCK_ORDER_ITEM_STATUS__DELIVERED
            });
        }
}

# Order again, total should increase, on_order_should_change
my $po = Test::XTracker::Data->setup_purchase_order([ $product_id ]);

$got = $product->get_ordered_item_quantity_details;

# Create comparison, this time the test method creates a quantity of 10
$expected = {
    $variant_id => {
        1 => {
            delivered_quantity => 0,
            on_order_quantity => 10,
            total_ordered_quantity => 50,
        },
    },
    $variant_id + 1 => ignore(),
};

cmp_deeply($got,$expected,'Quantities are as expected') or diag explain $got;

# create delivery for order
Test::XTracker::Data->create_delivery_for_po($po->id, 'qc');

$got = $product->get_ordered_item_quantity_details;

# Create comparison, this time the test method creates a quantity of 10
$expected = {
    $variant_id => {
        1 => {
            delivered_quantity => 10,
            on_order_quantity => 0,
            total_ordered_quantity => 50,
        },
    },
    $variant_id + 1 => ignore(),
};

cmp_deeply($got,$expected,'Quantities are as expected') or diag explain $got;

done_testing();

#!/usr/bin/env perl

=head1 NAME

edit-po-stock-booked-in - tests for EditPO features where stock is booked in

=head1 DESCRIPTION

The following EditPO features are tested with stock booked in (deliveries):

    * Size scheme changes not allowed
    * Size quantity changes allowed if new quantity >= stock delivered already
    * Size quantity changes not allowed if new quantity < stock delivered already
    * Stock Order Item, Stock Order and Purchase Order delivery status updated

#TAGS fulcrum json shouldbeservice purchaseorder inventory duplication delivery goodsin

=cut

use NAP::policy "tt", 'test';
use Test::XTracker::LoadTestConfig; # load config correctly
use JSON;
use Readonly;
use Test::XTracker::Data;
use Test::XT::DC::Mechanize;
use XTracker::Constants::FromDB qw(
    :delivery_status
    :delivery_type
    :delivery_item_status
    :delivery_item_type
    :stock_process_type
    :stock_process_status
    :stock_order_status
    :stock_order_item_status
    :purchase_order_status
);

Readonly my $DELIVERED => 6;
Readonly my $LESS_THAN_DELIVERED => 3;
Readonly my $MORE_THAN_DELIVERED => 10;

my $json    = JSON->new;
my $mech    = Test::XT::DC::Mechanize->new;
$mech->add_header(Accept => 'application/json');

my $schema = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

# Start transaction
my $guard = $schema->storage->txn_scope_guard;

# Get max variant id, required to stop duplicate variant key violation
my $max_variant = $schema->resultset('Public::Variant')->get_column('id')->max();
my @variant_array;
# Bump up the variant;
$max_variant += 20;
# Store an array of new variants which we can be sure don't exist
for (1 .. 7) {
    push @variant_array, ++$max_variant;
}

my $products = Test::XTracker::Data->find_or_create_products(
    {
        how_many            => 5,
        skip_measurements   => 1,
        force_create        => 1,
        how_many_variants   => 1,
    }
);
my @pids = map { $_->{pid} } @{ $products };

my $po = Test::XTracker::Data->setup_purchase_order(
    \@pids,
);

isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder', 'check type' );

# Commit transaction
$guard->commit;

$mech->get_ok('/api/purchase-orders/' . $po->purchase_order_number);

my $po_hash = decode_json($mech->content);
is($po_hash->{description}, 'test description', 'Description');

my $po_number = $po->purchase_order_number;
my $pid = $pids[0];

my @purchase_orders_found = $schema->resultset('Public::PurchaseOrder')->search(
    { 'stock_orders.product_id' => $pid },
    {
        join => 'stock_orders',
        select => ['purchase_order_number']
    }
);

my $data_from_fulcrum = {
        $pid => {
            name => "1-2-3",
            purchase_orders => {
                $po_number => {
                    quantities => {
                        "0" => 28,
                        "1" => 24,
                        "2" => 16,
                        "3" => 12,
                        "4" => 0,
                        "5" => 0,
                        "6" => 0
                    },
                },
            },
            sizes => {
               "0" => { designer_size => 0, variant_id => $variant_array[0] },
               "1" => { designer_size => 1, variant_id => $variant_array[1] },
               "2" => { designer_size => 2, variant_id => $variant_array[2] },
               "3" => { designer_size => 3, variant_id => $variant_array[3] },
               "4" => { designer_size => 4, variant_id => $variant_array[4] },
               "5" => { designer_size => 5, variant_id => $variant_array[5] },
               "6" => { designer_size => 6, variant_id => $variant_array[6] },
            },
        },
};

foreach my $po ( @purchase_orders_found ) {
    $data_from_fulcrum->{$pid}->{purchase_orders}->{$po->purchase_order_number}->{quantities} = {
        "0" => 1,
        "1" => 1,
        "2" => 2,
        "3" => 3,
        "4" => 4,
        "5" => 0,
        "6" => 8,
    };
}

my $encode_data_from_fulcrum = encode_json($data_from_fulcrum);


##################################
# link a StockProcess with a StockOrderItem to cause
# stock to appear to have been booked in
my $stock_order_item = $schema->resultset('Public::StockOrder')->search(
    {
        product_id        => $pid,
        purchase_order_id => $po->id
    }
)->single->stock_order_items->first;

# sanity check
can_ok($stock_order_item, 'quantity');

my $delivery = $schema->resultset('Public::Delivery')->create({
    status_id => $DELIVERY_STATUS__COUNTED,
    type_id => $DELIVERY_TYPE__STOCK_ORDER,
});

# another sanity check
can_ok($delivery, 'invoice_nr');

# we now need a delivery item
my $delivery_item = $delivery->create_related( delivery_items => {
    status_id => $DELIVERY_ITEM_STATUS__COMPLETE,
    type_id => $DELIVERY_ITEM_TYPE__STOCK_ORDER,
    quantity => $DELIVERED,
});

# do we still have sanity?
can_ok($delivery_item, 'packing_slip');


# We need a stock process attached to the delivery item
my $stock_process = $delivery_item->create_related( stock_processes => {
    type_id => $STOCK_PROCESS_TYPE__MAIN,
    status_id => $STOCK_PROCESS_STATUS__NEW,
});

# sanity?
can_ok($stock_process, 'quantity');

# now link the delivery item and to the stock order
my $link = $delivery_item->create_related( link_delivery_item__stock_order_items => {
    delivery_item_id => $delivery_item->id,
    stock_order_item_id => $stock_order_item->id,
});

# sanity?
can_ok($link, 'delivery_item_id');

my $product = $products->[0]->{product};

my $original_size_scheme_name = $product->product_attribute->size_scheme->name;
my $original_stock_order = $schema->resultset('Public::StockOrder')->search({
    product_id => $product->id,
    purchase_order_id => $po->id,
})->single;
my @original_stock_order_items = $original_stock_order->stock_order_items->all;

my $original_size_data_from_db;
foreach my $stock_order_item ( @original_stock_order_items ) {
        $original_size_data_from_db->{$stock_order_item->variant->size->size} = $stock_order_item->quantity;
}


$mech->put('/api/products/sizing', content => $encode_data_from_fulcrum);
ok(!$mech->success, 'Request failed validation');
is($mech->status, 400, '400 status returned');

$mech->content_like(qr{Validation Failed - Stock has been booked in for product});

is($product->product_attribute->size_scheme->name, $original_size_scheme_name, 'Size scheme product attribute not updated');

# Check new variants and stock order items have been created
my $getpo = $schema->resultset('Public::PurchaseOrder')->search( { purchase_order_number => $po_number })->single;
my $stock_order = $schema->resultset('Public::StockOrder')->search(
        {
            product_id => $pid,
            purchase_order_id => $getpo->id
        }
)->single;

is ( $stock_order->stock_order_items->count, @original_stock_order_items, 'Correct number of stock order items - remains the same');

$stock_order_item->update({status_id => $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED});

my $size_data_from_db;
my $stock_order_items = $stock_order->stock_order_items;
while ( my $stock_order_item = $stock_order_items->next ) {
        $size_data_from_db->{$stock_order_item->variant->size->size} = $stock_order_item->quantity;
}

is_deeply($size_data_from_db, $original_size_data_from_db, 'Sizes and quantities successfully updated');

########################################################################
# now create a quantities only update and ensure it works
my $p = $products->[0]->{product};

# sanity check - stock order items should not be delivered already
my $so = $schema->resultset('Public::StockOrder')->search({
    product_id => $p->id,
    purchase_order_id => $getpo->id,
})->single;

foreach my $soi ( $so->stock_order_items->all ) {
    isnt( $soi->status->id, $STOCK_ORDER_ITEM_STATUS__DELIVERED, 'Item has not been delivered' );
}


my $ss_name = $p->product_attribute->size_scheme->name;
my $quantities = {
    map
        { $_->size->size => $MORE_THAN_DELIVERED }
        $p->variants->all
};
my $sizes = {
    map {
            $_->size->size=> {
                designer_size => $_->designer_size_id,
                variant_id => $_->id
            }
    }
    $p->variants->all
};
my $quantities_only_api_data = {
            $p->id => {
            name => $ss_name,
            purchase_orders => {
                $po_number => {
                    quantities => $quantities,
                },
            },
            sizes => $sizes,
        },
};

$mech->put(
    '/api/products/sizing',
    content => encode_json( $quantities_only_api_data ),
);
ok( $mech->success, 'Can update quantities with stock booked in' );

# As we set the quantities to more than delivered ( 10 ) and one item has been delivered,
# the stock order status should be part delivered.
$so->discard_changes;
$so->purchase_order->discard_changes;

foreach my $soi ( $so->stock_order_items->all ) {
    is(
        $soi->status_id,
        $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED,
        'Quantity change updates stock order item status'
    );
}

is(
    $so->status_id,
    $so->check_status,
    'Quantity change also updates stock order status',
);

is(
    $so->purchase_order->status_id,
    $so->purchase_order->check_status,
    'Quantity change also updates purchase order status',
);

isnt(
    $so->purchase_order->check_status,
    $PURCHASE_ORDER_STATUS__ON_ORDER,
    'Purchase order should not be ON ORDER after a delivery',
);

##########################################################
# test for PM-1284
# should not be able to update quantity to less than delivered quantity

$quantities_only_api_data
    ->{$pid}->{purchase_orders}->{$po_number}->{quantities} = {
    map
        { $_->size->size => $LESS_THAN_DELIVERED }
        $p->variants->all
};
$mech->put(
    '/api/products/sizing',
    content => encode_json( $quantities_only_api_data ),
);
ok( !$mech->success, 'Cannot update quantity to less than already delivered' );

$mech->content_like(
    qr/Cannot update quantity.*less than already delivered/,
    'Correct error message shown when quantity is less than delivered'
);

foreach my $soi( $so->stock_order_items->all ) {
    is(
        $soi->quantity,
        $MORE_THAN_DELIVERED,
        'Quantity is what we set it to (more than has already been delivered)',
    );
}


# Should be able to update quantity to exactly the same as the delivered
# quantity and the stock_order status should be delivered.
my $quantities_same_as_delivered = {
    map
        { $_->size->size => $DELIVERED }
        $p->variants->all
};
my $sizes_same_as_delivered = {
    map {
            $_->size->size=> {
                designer_size => $_->designer_size_id,
                variant_id => $_->id
            }
    }
    $p->variants->all
};
my $quantities_only_api_data_same_as_delivered = {
            $p->id => {
            name => $ss_name,
            purchase_orders => {
                $po_number => {
                    quantities => $quantities_same_as_delivered,
                },
            },
            sizes => $sizes_same_as_delivered,
        },
};

$mech->put(
    '/api/products/sizing',
    content => encode_json( $quantities_only_api_data_same_as_delivered ),
);
ok( $mech->success, 'Can update quantities with stock booked in' );

# As we set the quantities to same as delivered ( 6 ) and one item has been delivered,
# the stock order status should be delivered.
$so->discard_changes;
$so->purchase_order->discard_changes;

foreach my $soi ( $so->stock_order_items->all ) {
    is(
        $soi->status_id,
        $STOCK_ORDER_ITEM_STATUS__DELIVERED,
        'Quantity change updates stock order item status'
    );
}

is(
    $so->status_id,
    $so->check_status,
    'Quantity change also updates stock order status',
);

is(
    $so->purchase_order->status_id,
    $so->purchase_order->check_status,
    'Quantity change also updates purchase order status',
);

isnt(
    $so->purchase_order->check_status,
    $PURCHASE_ORDER_STATUS__ON_ORDER,
    'Purchase order should not be ON ORDER after a delivery',
);


done_testing();

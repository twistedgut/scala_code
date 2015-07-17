#!/usr/bin/env perl

=head1 NAME

editpo-update_sizes - Test for EditPO size quantities update

=head1 DESCRIPTION

Tests updates of size quantities for EditPO (not size scheme updated, which
have their own tests).

#TAGS fulcrum json shouldbeservice purchaseorder inventory duplication

=cut

use NAP::policy "tt", 'test';
use Test::XTracker::LoadTestConfig; # load config correctly

use JSON;

use Test::XTracker::Data;
use Test::XT::DC::Mechanize;
use Readonly;
use Storable qw[ dclone ];
use XTracker::Constants::FromDB qw(
    :stock_order_status
    :stock_order_type
);

# The quantity of goods we will order. Arbitrary, but we will check it is set
Readonly my $QUANTITY_TO_ORDER => 33;
Readonly my $OTHER_QUANTITY_TO_ORDER => 12;

# The first variant ID to send. We will send sequentially after that.
Readonly my $FIRST_VARIANT_ID => 999999650;
my $json    = JSON->new;
my $mech    = Test::XT::DC::Mechanize->new;
$mech->add_header(Accept => 'application/json');

my $schema = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

# Start transaction
my $guard = $schema->storage->txn_scope_guard;

my $products = Test::XTracker::Data->find_or_create_products({
    how_many => 5,
    avoid_one_size => 1,
    force_create => 1,
} );
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

my $get_size_scheme = get_size_scheme( $pid );

# The data we'll send to the API (as is sent by Fulcrum)
# some helper references into the deep structure
my $pid_request_data = {};
$pid_request_data->{ name } = $get_size_scheme->size_scheme->name;
$pid_request_data->{ currently_editing } = $po_number;

my $po_request_data = {};

$pid_request_data->{purchase_orders} = { $po_number => $po_request_data };

my $api_request_data = { $pid => $pid_request_data };

# Fulcrum sends variant IDs to the API
# We will create some made up variant ID starting at the constant
my $made_up_variant_id = $FIRST_VARIANT_ID;

# How many items we order - will be used to check number of stock order items
my $stock_order_items_on_order = 0;

# Whether to order the next item. Flag will be flipped in loop so that we order
# alternate items. This is to test that zero-quantity stock orders are not
# created.
my $to_order = 1;

foreach my $size ( $get_size_scheme->size_scheme->sizes ) {
    # populate the incoming data for each PO
    foreach my $po ( @purchase_orders_found ) {
        $po_request_data
            ->{quantities}
            ->{$size->size} = 0
    }
    # how much to order? zero or constant
    my $quantity;
    if ( $to_order ) {
        $quantity = $QUANTITY_TO_ORDER;
        $to_order = 0;
        $stock_order_items_on_order++;
    }
    else {
        $quantity = 0;
        $to_order = 1;
    }
    $po_request_data
        ->{ quantities }
        ->{ $size->size } = $quantity;

    # set a made up variant id
    $pid_request_data->{sizes}->{ $size->size }->{variant_id}
        = $made_up_variant_id++;
}

my $encode_api_request_data = encode_json($api_request_data);
$mech->put_ok('/api/products/sizing', {content => $encode_api_request_data});
ok($mech->success, 'Request succeeeded');
is($mech->status, 200, '200 status returned');

my $product = $schema->resultset('Public::Product')->find($pid);

is(
    $product->product_attribute->size_scheme->name,
    $pid_request_data->{name},
    'Size scheme has not changed'
);

# Find existing sizes and check if quantity is what we sent
my $getpo = $schema->resultset('Public::PurchaseOrder')
    ->search( { purchase_order_number => $po_number })->single;

my $stock_order = $schema->resultset('Public::StockOrder')->search(
        {
            product_id => $pid,
            purchase_order_id => $getpo->id
        }
)->single;

# Filter cancelled stock order items out.
my $stock_order_items_created = $stock_order->stock_order_items->search({ cancel => 0, });

is (
    $stock_order_items_created->count,
    $stock_order_items_on_order,
    'Correct number of stock order items created'
);

# Check that the stock orders were created as expected
# We expect them to be as we sent, except for zero-quantity items
my $expected_size_data = dclone( $po_request_data->{quantities} );
# if the quantity is zero, we don't want a stock_order_item
foreach my $size_name ( keys %{$expected_size_data//{}} ) {
    if ( $expected_size_data->{ $size_name } == 0 ) {
       delete $expected_size_data->{$size_name};
    }
}

# Build an equivalent hash from the DB to compare with what we sent
my $size_data_from_db;
while ( my $stock_order_item = $stock_order_items_created->next ) {
    my $size_name = $stock_order_item->variant->size->size;

    $size_data_from_db->{$size_name} = $stock_order_item->quantity;
}

note ( "Updated quantities for sizes: ".p($size_data_from_db));

cmp_deeply(
    $size_data_from_db,
    $expected_size_data,
    'Sizes and quantities successfully updated'
);

# now we'll change quantities and do it again...
{
    my $q = $po_request_data->{quantities};
    $stock_order_items_on_order = 0;
    foreach my $size ( keys %{ $q } ) {
        # order everything we didn't order, cancel everything we did...
        if ( $q->{$size} ) {
            $q->{$size} = 0;
        }
        else {
            $q->{$size} = $QUANTITY_TO_ORDER;
            $stock_order_items_on_order++;
        }
    }
}

# update the api with the new quantities
$encode_api_request_data = encode_json($api_request_data);
$mech->put_ok('/api/products/sizing', {content => $encode_api_request_data});
ok($mech->success, 'Request succeeeded');
is($mech->status, 200, '200 status returned');
my $stock_order_items = $stock_order->stock_order_items->search({ cancel => 0, });

is (
    $stock_order_items->count,
    $stock_order_items_on_order,
    'Correct number of stock order items created'
);

# Check that the stock orders were created as expected
# We expect them to be as we sent, except for zero-quantity items
$expected_size_data = dclone( $po_request_data->{quantities} );
# if the quantity is zero, we don't want a stock_order_item
foreach my $size_name ( keys %{$expected_size_data//{}} ) {
    if ( $expected_size_data->{ $size_name } == 0 ) {
       delete $expected_size_data->{$size_name};
    }
}

$size_data_from_db = get_size_data_from_db( $stock_order_items );

note ( "Updated quantities for sizes: ".p($size_data_from_db));

cmp_deeply(
    $size_data_from_db,
    $expected_size_data,
    'Sizes and quantities successfully updated'
);


# add another stock order item of type replacement for the product in question
$po->create_related(
    'stock_orders' => {
        product_id => $stock_order->product_id,
        status_id => $STOCK_ORDER_STATUS__ON_ORDER,
        type_id => $STOCK_ORDER_TYPE__REPLACEMENT,
    }
);

# create a new set of quantities (payload for the API)
foreach my $size_name ( keys %{$expected_size_data//{}} ) {
    $expected_size_data->{$size_name} = $OTHER_QUANTITY_TO_ORDER;
    $po_request_data
        ->{ quantities }
        ->{ $size_name } = $OTHER_QUANTITY_TO_ORDER;

}



# send size update request with the new quantities
$mech->put_ok('/api/products/sizing', {content => encode_json($api_request_data)});

# check the new quantities were applied

$size_data_from_db = get_size_data_from_db( $stock_order_items );

note ( "Updated quantities for sizes: ".p($size_data_from_db));

cmp_deeply(
    $size_data_from_db,
    $expected_size_data,
    'Sizes and quantities successfully updated'
);

done_testing();

sub get_size_scheme {
    my ( $product ) = shift;

    return $schema->resultset('Public::ProductAttribute')->search(
        {
            product_id => $product,
        },
        {
            join => 'size_scheme'
        }
    )->single;
}

sub get_size_data_from_db {
    my ( $stock_order_items ) = @_;
    # Build an equivalent hash from the DB to compare with what we sent
    my $size_data_from_db = {};
    $stock_order_items->reset;
    while ( my $stock_order_item = $stock_order_items->next ) {
        my $size_name = $stock_order_item->variant->size->size;

        $size_data_from_db->{$size_name} = $stock_order_item->quantity;
    }
    return $size_data_from_db;
}

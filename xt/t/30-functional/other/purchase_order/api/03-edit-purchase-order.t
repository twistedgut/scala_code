#!/usr/bin/env perl
# vim: set ts=4 sw=4 sts=4:

=head1 NAME

03-edit-purchase-order.t - test size scheme can be changed

=head1 DESCRIPTION

Create test products and a purchase order and then build mock data which would
normally be sent from fulcrum when requesting a size scheme change.

Send size scheme change to REST API and test:

    * size scheme update is successful
    * correct number of stock order items exist after successful update
    * correct variant id stored against stock order item
    * standardised sizes updated
    * correct quantities and sizes updated

#TAGS fulcrum json shouldbeservice purchaseorder inventory duplication

=cut

use NAP::policy "tt", 'test';

use FindBin::libs;

use JSON;

use Test::XTracker::Data;
use Test::XT::DC::Mechanize;
use Storable qw[ dclone ];

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

my $products = Test::XTracker::Data->find_or_create_products( { how_many => 5, skip_measurements=>1, force_create => 1 } );
my @pids = map { $_->{pid} } @{ $products };

my $po = Test::XTracker::Data->setup_purchase_order(
    \@pids,
);

isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder', 'check type' );

note(  "New product has size scheme " . $products->[0]->{product}->product_attribute->size_scheme->name );


# Commit transaction
$guard->commit;

$mech->get_ok('/api/purchase-orders/' . $po->purchase_order_number);

my $po_hash = decode_json($mech->content);
is($po_hash->{description}, 'test description', 'Description');

my $po_number = $po->purchase_order_number;

my @purchase_orders_found = $schema->resultset('Public::PurchaseOrder')->search(
    { 'stock_orders.product_id' => $pids[0] },
    {
        join => 'stock_orders',
        select => ['purchase_order_number']
    }
);

my $data_from_fulcrum = {
        $pids[0] => {
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
    $data_from_fulcrum->{$pids[0]}->{purchase_orders}->{$po->purchase_order_number}->{quantities} = {
        "0" => 1,
        "1" => 1,
        "2" => 2,
        "3" => 3,
        "4" => 4,
        "5" => 0,
        "6" => 8,
    };
}

# $data_from_fulcrum - mock data setup to mimic data that the fulcrum rest client would
# send on size scheme update to XT
my $encode_data_from_fulcrum = encode_json($data_from_fulcrum);
$mech->put_ok('/api/products/sizing', {content => $encode_data_from_fulcrum});
ok($mech->success, 'Request succeeeded');
is($mech->status, 200, '200 status returned');

my $product = $schema->resultset('Public::Product')->find($pids[0]);
is($product->product_attribute->size_scheme->name, $data_from_fulcrum->{$pids[0]}->{name}, 'Size scheme successfully updated');

# Check new variants and stock order items have been created
my $getpo = $schema->resultset('Public::PurchaseOrder')->search( { purchase_order_number => $po_number })->single;

my $stock_order = $schema->resultset('Public::StockOrder')->search(
        {
            product_id => $pids[0],
            purchase_order_id => $getpo->id
        }
)->single;

is ( $stock_order->stock_order_items->count, 6, 'Correct number of stock order items created');

my $size_data_from_db;
my $stock_order_items = $stock_order->stock_order_items;

my $size_scheme = $schema->resultset('Public::SizeScheme')->search(
    {
        name => $data_from_fulcrum->{$pids[0]}->{name}
    }
)->single;

while ( my $stock_order_item = $stock_order_items->next ) {
        $size_data_from_db->{$stock_order_item->variant->size->size} = $stock_order_item->quantity;
        is(
            $stock_order_item->variant->id,
            $data_from_fulcrum
                ->{ $pids[0] }
                ->{sizes}
                ->{ $stock_order_item->variant->size->size }
                ->{ variant_id },
            'Variant was created with specified ID'
        );

        my $std_size_mapping = $schema->resultset('Public::StdSizeMapping')->search(
            {
                'me.size_id' => $stock_order_item->variant->designer_size_id,
                'me.size_scheme_id' => $size_scheme->id,
            },
        )->single;

        # Check if standardised sizes were updated
        if ( $std_size_mapping ) {
            is(
                $stock_order_item->variant->std_size_id,
                $std_size_mapping->std_size->id,
                'Standardised size update for variant'
            );
        }
}

# Looping through all quantities and delete key value if quantity = 0.
# Doing this as we do not create any stock_order_items for quantitities that are 0

# Deleting from a copy so that we can use the original in later tests.
my $expected_sizes_and_quantities = dclone($data_from_fulcrum->{$pids[0]}->{purchase_orders}->{$po_number}->{quantities});

while ( my ( $size_key, $quantity_val ) = each %{ $expected_sizes_and_quantities } ) {
    delete $expected_sizes_and_quantities->{$size_key} if $quantity_val == 0;
}

is_deeply($size_data_from_db, $expected_sizes_and_quantities, 'Sizes and quantities successfully updated');

# Test rollback data

my $second_data_from_fulcrum = dclone( $data_from_fulcrum );
$second_data_from_fulcrum->{$pids[0]}->{purchase_orders}->{$po_number}->{quantities}->{"0"} = 42;

$mech->put_ok('/api/products/sizing', {content => encode_json( $second_data_from_fulcrum )});
ok($mech->success, 'Request succeeeded');
is($mech->status, 200, '200 status returned');

my $rollback_data = $mech->content;

# The rollback data send from the second request should be equal to the
# data sent in the first request ($data_from_fulcrum)

is_deeply(decode_json($rollback_data)->{previous_sizing_data}, $data_from_fulcrum, 'The rollback data matches the sizing that was just PUT in XT');

done_testing();

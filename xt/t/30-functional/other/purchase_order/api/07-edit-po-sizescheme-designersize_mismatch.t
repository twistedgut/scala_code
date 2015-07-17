#!/usr/bin/env perl
# vim: set ts=4 sw=4 sts=4:

=head1 NAME

07-edit-po-sizescheme-designersize_mismatch.t - tests that a size scheme change is not possible if designer sizes do not match

=head1 DESCRIPTION

Creates test products and a purchase order and build mock data which would
normally be sent from fulcrum. This data contains size scheme and quantity
information for products within purchase orders.

Attempt to make a size scheme change via the REST API, expects the update
to fail as the data we are sending in $data_from_fulcrum has designer size(s)
which are not found in XT.

We can not make a size scheme change in this scenario until the data across
systems is synced.

#TAGS fulcrum json shouldbeservice purchaseorder inventory duplication

=cut

use NAP::policy "tt", 'test';

use FindBin::libs;

use JSON;

use Test::XTracker::Data;
use Test::XT::DC::Mechanize;
my $json    = JSON->new;
my $mech    = Test::XT::DC::Mechanize->new;
$mech->add_header(Accept => 'application/json');

my $schema = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

# Start transaction
my $guard = $schema->storage->txn_scope_guard;

my $products = Test::XTracker::Data->find_or_create_products(
    {
        how_many          => 5,
        skip_measurements => 1,
        force_create      => 1
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
               "0" => { designer_size => '0', variant_id => 87870 },
               "1" => { designer_size => '1', variant_id => 87871 },
               "2" => { designer_size => '2', variant_id => 87872 },
               "3" => { designer_size => '3', variant_id => 87873 },
               "4" => { designer_size => '4', variant_id => 87874 },
               "5" => { designer_size => '42', variant_id => 87916 },
               "6" => { designer_size => '6', variant_id => 87876 },
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

my $encode_data_from_fulcrum = encode_json($data_from_fulcrum);

$mech->put('/api/products/sizing', content => $encode_data_from_fulcrum);

ok(!$mech->success, 'Request failed');

is($mech->status, 400, '400 status returned');

$mech->content_like(qr/An error occurred updating the sizing: Validation Failed - Designer size : \d+ in data from fulcrum does not match size in database/);

done_testing;

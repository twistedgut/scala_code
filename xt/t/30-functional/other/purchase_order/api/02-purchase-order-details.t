#!/usr/bin/env perl

=head1 NAME

02-purchase-order-details.t - test purchase order detail changes can be made in XT

=head1 DESCRIPTION

Create some products and setup a purchase order.

Send purchase order update to REST API for products created above.

Details sent include:

    - Cancelling a stock order
    - Ship Date update
    - Cancel Date update
    - Window Type update
    - Original Cost price update

#TAGS fulcrum json shouldbeservice purchaseorder inventory duplication

=cut

use NAP::policy "tt", 'test';

use FindBin::libs;

use JSON;

use Test::XTracker::Data;
use Test::XT::DC::Mechanize;
use Test::Differences;
use DateTime::Format::Strptime;
use Storable "dclone";
my $json    = JSON->new;
my $mech    = Test::XT::DC::Mechanize->new;
$mech->add_header(Accept => 'application/json');

my $schema = Test::XTracker::Data->get_schema();
isa_ok($schema, 'XTracker::Schema',"Schema Created");

# Start transaction
my $guard = $schema->storage->txn_scope_guard;

my $products = Test::XTracker::Data->find_or_create_products( { how_many => 2, skip_measurements => 1, force_create => 1} );

my @pids = map { $_->{pid} } @{ $products };

is (@pids, 2, "Expects 2 products to be found");

note "Working with pids: ". p @pids;

my $po = Test::XTracker::Data->setup_purchase_order(
    \@pids,
);

isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder', 'check type' );

note "Purchase order number is: ",$po->purchase_order_number;

# Commit transaction
$guard->commit;

my $parser = DateTime::Format::Strptime->new( pattern => '%Y-%m-%d %T' );

sub get_products_from_db {
    my @pids = @_;
    my @products_from_db =
      $schema->resultset('Public::StockOrder')->search( { product_id => \@pids, } );

    my $po_hash;
    foreach my $stock_order (@products_from_db) {
        $po_hash->{ $stock_order->product_id } = {
            start_ship_date         => $parser->format_datetime( $stock_order->start_ship_date ),
            cancel_ship_date        => $parser->format_datetime( $stock_order->cancel_ship_date ),
            shipment_window_type_id => $stock_order->shipment_window_type_id,
            original_wholesale => $stock_order->public_product->price_purchase->original_wholesale,
            wholesale_price    => $stock_order->public_product->price_purchase->wholesale_price,
            cancel             => $stock_order->cancel,
        };
    }

    return $po_hash;
}

my $initial_hash = get_products_from_db(@pids);

is (keys %$initial_hash, 2, "Expects 2 products to be returned from XT");

my @three_random_products = $schema->resultset('Public::Product')->search( {},{ order_by => 'random()', rows => 3 });

# Mock data from fake fulcrum, data will be sent in the app from a REST client in Fulcrum.
my $purchase_order_details;

# PID 1 - contains a cancellation
$purchase_order_details->{ $pids[0] } = {
    ship_date             => "2013-02-01 13:21:10",
    cancel_date           => "2013-09-02 13:21:20",
    shipment_window_type  => 1,
    original_wholesale    => "463.000",
    wholesale_cost        => "302.000",
    cancel                => 1,
};

# PID 2 - does not contain a cancellation
$purchase_order_details->{ $pids[1] } = {
    ship_date            => "2013-04-01 12:34:09",
    cancel_date          => "2013-12-02 17:14:24",
    shipment_window_type => 1,
    original_wholesale   => "909.000",
    wholesale_cost       => "812.000",
    cancel               => 0,
};

# Send purchase order update $purchase_order_details via REST
$mech->put_ok('/api/purchase-orders/' . $po->purchase_order_number . '/core-data', { content => encode_json($purchase_order_details) });

# Should have a copy of the previous data in the db, in case we need to rollback
my $previous_data_hash = decode_json $mech->content;

# Checking rollback data exists
eq_or_diff([keys %$previous_data_hash], ["previous_core_data"], "Rollback data as expected");

# note "Rollback data is: ".p $previous_data_hash;
is(scalar keys %{$previous_data_hash->{previous_core_data}}, 2, "2 products to rollback");

# Now check the update via REST was successful
my $stock_orders_from_db = $schema->resultset('Public::StockOrder')
    ->search( { purchase_order_id => $po->id } );

my $stock_order_data_from_db = {};
while ( my $stock_order = $stock_orders_from_db->next ) {
    $stock_order_data_from_db->{ $stock_order->product_id } = {
        ship_date            => $parser->format_datetime( $stock_order->start_ship_date ),
        cancel_date          => $parser->format_datetime( $stock_order->cancel_ship_date ),
        shipment_window_type => $stock_order->shipment_window_type_id,
        original_wholesale   => $stock_order->public_product->price_purchase->original_wholesale,
        wholesale_cost       => $stock_order->public_product->price_purchase->wholesale_price,
        cancel               => $stock_order->cancel,
    };

    # Check the cancel status of the stock order items
    my $stock_order_items = $stock_order->stock_order_items;
    while ( my $stock_order_item = $stock_order_items->next ) {
        is( $stock_order_item->cancel, $stock_order->cancel,
            "Cancellation status correctly reflects it's parent stock order cancel status of "
            . $stock_order->cancel
        );
    }

}

# Check the data sent via REST matches that stored in the database
is_deeply( $stock_order_data_from_db, $purchase_order_details, 'Data successfully stored in db' );


done_testing;

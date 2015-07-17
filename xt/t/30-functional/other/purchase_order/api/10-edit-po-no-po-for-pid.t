#!/usr/bin/env perl

=head1 NAME

10-edit-po-no-po-for-pid - test size updates for pid with no purchase order

=head1 DESCRIPTION

Create test products and setup purchase order. Attempt a size scheme update
and check that for pid with a purchase order size scheme is changed and
variants updated, but for a pid with no purchase order we just update the
size scheme in the product table.

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


my $products = Test::XTracker::Data->find_or_create_products( {
    how_many => 5, skip_measurements=>1, force_create => 1,
} );
my @pids = map { $_->{pid} } @{ $products };

my $pid = $pids[0];
my $product = $schema->resultset('Public::Product')->find( $pid );

# We do not want a purchase order for this product.
# We are checking we can update products without a PO.
foreach ( $product->stock_order->all ) {
    $_->stock_order_items->delete;
    $_->delete;
}

my $next_variant_id =
    $schema
        ->resultset('Public::Variant')
        ->get_column('id')
        ->max;

my $sizes = {};
my @expected_variants;
for ( 0 .. 6 ) {
    $next_variant_id++;
    $sizes->{$_} = { designer_size => $_, variant_id => $next_variant_id };
    push @expected_variants, $next_variant_id;
}

my $request_content = {
        # check an existing product with no PO specified is still updated
        $pids[0] => {
            name => "1-2-3",
            sizes => $sizes,
        },
        # non-existing product should be skipped as no PO specified
        1616161 => {
            name => '1-2-3',
            sizes => {
                0 => { designer_size => 0, variant_id => 6161616 },
            }
        }
};

my $request_json = encode_json($request_content);

$mech->put_ok( '/api/products/sizing', {content => $request_json} );

is( $mech->status, 200, '200 status returned' );

# check that the skipped product was listed

my $response;
eval {
    $response = decode_json($mech->content);
};
is_deeply(
    $response->{skipped_pids},
    [ 1616161 ],
    'Non-existent PID was skipped'
);

is(
    $product->product_attribute->size_scheme->name,
    $request_content->{$pids[0]}->{name},
    'Size scheme has changed'
);

is( $product->variants->all, 7, "seven variants found" );
is_deeply(
    [
        sort
        map
            { $_->id }
            $product->variants->all,
    ],
    \@expected_variants,
    "variants updated as expected",
);


done_testing;

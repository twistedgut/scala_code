#!perl

=head1 NAME

pre_order_search.t - Test the pre_order search module

=head1 DESCRIPTION

Tests the pre-order search function

#TAGS movetounit search todo misc loops

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data::PreOrder;
use Test::XT::Flow;

use Test::XT::Flow;

use XTracker::Database qw(:common);
use XTracker::Database::Reservation qw( get_reservation_variants);
use XTracker::Database::Stock qw( get_ordered_item_quantity );
use XTracker::Constants::FromDB qw(:authorisation_level);

use_ok('XTracker::Order::CustomerCare::PreOrderSearch::Search');
use XTracker::Order::CustomerCare::PreOrderSearch::Search qw( :search );

my $framework =  Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Channel',
        'Test::XT::Data::Customer',
        'Test::XT::Data::PreOrder',
    ],
);

my $schema = $framework->schema;

$framework->login_with_permissions({
    perms => {
        $AUTHORISATION_LEVEL__MANAGER => [
            'Stock Control/Reservation',
        ],
    },
    dept => 'Customer Care Manager',
});

# Step 1 - Create Pre-Order for a customer
my $pre_order = $framework->pre_order;
# need a Post Code for the Tests
$pre_order->invoice_address->update( { postcode => 'TE5 1ST' } )
                unless ( $pre_order->invoice_address->postcode );
my @variants = @{ $framework->variants };

# Step 2 - Run the searches against the above pre_order
my $search_types = [
    {
        search_type     => 'customer_number',
        valid_terms     => $pre_order->customer_id,
        description     => 'Valid Customer Number',
    },
    {
        search_type     => 'customer_name',
        valid_terms     => join(' ', ($pre_order->customer->first_name, $pre_order->customer->last_name ) ),
        description     => 'Customer Name',
    },
    {
        search_type     => 'first_name',
        valid_terms     => $pre_order->customer->first_name,
        description     => 'Customer First Name',
    },
    {
        search_type     => 'last_name',
        valid_terms     => $pre_order->customer->last_name,
        description     => 'Customer Last Name',
    },
    {
        search_type     => 'pre_order_number',
        valid_terms     => $pre_order->id,
        description     => 'Valid Pre-Order Number',
    },
    {
        search_type     => 'product_id',
        valid_terms     => $variants[0]->product_id,
        description     => 'Valid Product ID',
    },
    {
        search_type     => 'sku',
        valid_terms     => join( '-', ( $variants[0]->product_id, $variants[0]->size_id ) ),
        description     => 'Valid SKU',
    },
    {
        search_type     => 'billing_address',
        valid_terms     => $pre_order->invoice_address->address_line_1,
        description     => 'Billing Address',
    },
    {
        search_type     => 'shipping_address',
        valid_terms     => $pre_order->shipment_address->address_line_1,
        description     => 'Shipping Address',
    },
    {
        search_type     => 'postcode',
        valid_terms     => $pre_order->invoice_address->postcode,
        description     => 'PostCode/Zip',
    },
    {
        search_type     => 'telephone_number',
        valid_terms     => $pre_order->telephone_day,
        description     => 'Telephone Number',
    },
];

run_search_tests();

sub run_search_tests {
    throws_ok( sub { find_pre_orders() }, qr/No schema object passed/, 'Catches no schema object');
    throws_ok( sub { find_pre_orders( $schema ) }, qr/No search type provided/, 'Catches no search type');
    throws_ok( sub { find_pre_orders($schema, { search_type => 'pre_order_number' } ) },
        qr/No search terms/, 'Catches no search terms' );
    foreach my $test ( @$search_types ) {
        my $result = find_pre_orders($schema, {
            search_type => $test->{search_type},
            search_terms => $test->{valid_terms}
        } );

        my @keys = sort keys %$result;
        ok( ( ($keys[0] == $pre_order->id) || (scalar @keys > 1) ), $test->{description} );
    }
}

done_testing;

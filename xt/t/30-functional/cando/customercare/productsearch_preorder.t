#!/usr/bin/perl
use NAP::policy "tt",     'test';

=head1 NAME

productsearch_preorder.t - Tests the Pre-Order Tab on the Product Reservation page

=head1 DESCRIPTION

Tests the Reservation & Pre-Order tabs that are on the Product Reservation summary page which
lists all Reservations & Pre-Orders for a Product. This page is reached by searching for a Product
from the 'Stock Control->Reservation' Main Nav option and then using the 'Product' Left Hand Menu
option under the 'Search' heading.

It tests that Pre-Orders are in the Pre-Order TAB and that Reservations are in the Reservation TAB
and that only Pre-Order related column headings are in the Pre-Order tab.

#TAGS inventory reservation preorder inline cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;

use Data::Dumper;
use Test::XT::Flow;
use XTracker::Database::Reservation qw( get_reservation_variants );
use XTracker::Database::Stock qw( get_ordered_item_quantity );
use XTracker::Constants::FromDB qw( :authorisation_level );

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Channel',      # required for PreOrder
        'Test::XT::Data::Customer',     # required for PreOrder
        'Test::XT::Data::PreOrder',
        'Test::XT::Flow::Reservations',
    ],
);

my $dbh = $framework->schema->storage->dbh;

$framework->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Reservation',
            ],
        },
        dept => 'Customer Care Manager',
    });

# Step 1: Create pre-order for a customer
my $pre_order   = $framework->pre_order;
my $reservations = $framework->reservations;

# get all the variants for the above pre-order
my @variants    = @{ $framework->variants };

# Step 2: Create pre-order for different customer for same variants as above
my $pre_order2      = Test::XTracker::Data::PreOrder->create_pre_order_for_variants(\@variants);

# turn on Pre-Order functionality
my $orig_state  = Test::XTracker::Data::PreOrder->set_pre_order_active_state_for_channel( $framework->channel, 1 );

foreach my $variant ( @variants) {

    my $product_id  =  $variant->product_id;


    # create po for given variant
    my $po = Test::XTracker::Data->setup_purchase_order( $product_id);

    note "Create purchase order **************". $po->id;


    my $reservations  = get_reservation_variants($dbh, $product_id);
    my $stock         = get_ordered_item_quantity($dbh, $product_id);

    # Step 3: Got To product Search page
    $framework->mech__reservation__product_search
            ->mech__reservation__product_search_submit(
                    { product_id => $product_id, }
                );

    my $page_data = $framework->mech->as_data->{reservation_list}{ $framework->channel->name };
    my $preorder_data = $page_data->{'preorder'}{$variant->id }{customers};

    my $reservation_data = $page_data->{'reservation'}{$variant->id }{customers};

    note "Test reservation tab does not have shipping window";
    my $window_data = $page_data->{'reservation'}{$variant->id }{variant}[0];
    ok( ! exists $window_data->{'Shipping Window'},"Reservation Tab does NOT have shipping window heading");

    note "Test pre-order tab for Shipping Window heading ";
    $window_data = $page_data->{'preorder'}{$variant->id }{variant}[0];
    ok( exists $window_data->{'Shipping Window'},"Pre-Order Tab has heading Shipping Window");
    my $window_date = $variant->get_estimated_shipping_window();
    my $date = $window_date->{start_ship_date}." - ".$window_date->{cancel_ship_date};
    cmp_ok( $window_data->{'Shipping Window'}, 'eq', $date," Shipping window date is correctly displayed");



    note "Test reservation Tab does NOT have Customer record";
    my $count_reservation_order = grep { $_->{'No.'} == $pre_order->customer->is_customer_number } @ { $reservation_data };
    cmp_ok( $count_reservation_order,'==', 0, " No Reservations for First Customer: ". $pre_order->customer->is_customer_number );

    $count_reservation_order = grep { $_->{'No.'} == $pre_order2->customer->is_customer_number } @ { $reservation_data };
    cmp_ok( $count_reservation_order,'==', 0, " No Reservations for Second Customer: ". $pre_order2->customer->is_customer_number );

    note "Check if Available Stock column exists";
    ok(exists $page_data->{'reservation'}{$variant->id }{variant}[0]->{'Available Stock'}, "Available Stock column appears");

    #check if Available Stock value displayed is correct
    my $free_stock = $stock->{$framework->channel->name}->{$variant->id} -  $reservations->{$framework->channel->name}->{$variant->id}{preorder_count};
    cmp_ok( $page_data->{'reservation'}{$variant->id }{variant}[0]->{'Available Stock'}, '==', $free_stock, "Available Stock value is correct" );


    note "Test pre-order Tab has Customer record";

    my $count_pre_order = grep { $_->{'No.'}{'value'} == $pre_order->customer->is_customer_number } @ { $preorder_data };
    cmp_ok( $count_pre_order, ' ==', 1, "Pre-order is Listed for First Customer: ". $pre_order->customer->is_customer_number );

    $count_pre_order = grep { $_->{'No.'}{'value'} == $pre_order2->customer->is_customer_number } @ { $preorder_data };
    cmp_ok( $count_pre_order, '==', 1, "Pre-order is Listed for First Customer: ". $pre_order2->customer->is_customer_number );

    #check if Available Stock value displayed is correct
    cmp_ok( $page_data->{'reservation'}{$variant->id }{variant}[0]->{'Available Stock'}, '==', $free_stock, "Available Stock value is correct" );

}

# restore original state of Pre-Order functionality
Test::XTracker::Data::PreOrder->set_pre_order_active_state_for_channel( $framework->channel, $orig_state );

done_testing;

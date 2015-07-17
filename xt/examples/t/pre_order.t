#!/usr/bin/perl
use NAP::policy "tt",     'test';

=head2 Example Test File for Creating Pre-Orders

This shows people how to create Pre-Orders for their Tests.

=cut

use Test::XTracker::Data;

# ONE WAY TO USE THE FUNCTIONALITY
use Test::XT::Data;

my $framework = Test::XT::Data->new_with_traits(
    traits => [
        'Test::XT::Data::Channel',      # required for PreOrder
        'Test::XT::Data::Customer',     # required for PreOrder
        'Test::XT::Data::PreOrder',
    ],
);

# these two commands will use the SAME Pre-Order
my $pre_order   = $framework->pre_order;
my $reservations= $framework->reservations;


# ANOTHER WAY TO USE THE FUNCTIONALITY
use Test::XTracker::Data::PreOrder;

# these two commands will create 2 DIFFERENT Pre-Orders
$pre_order      = Test::XTracker::Data::PreOrder->create_complete_pre_order;
$reservations   = Test::XTracker::Data::PreOrder->create_pre_order_reservations;

# this will create an Order linked to a Pre-Order
my $order       = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order;


done_testing;

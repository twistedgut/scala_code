#!perl

=head1 NAME

order_search_results.t - Test the order search function on the XT web interface

=head1 DESCRIPTION

Verifies that order search on the site functions by validating a single piece
of returned data. Relies upon order_search.t test to validate that order search
functions for other data.

#TAGS search misc

=cut

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB qw( :authorisation_level
                                    :customer_category );

my $mech = Test::XTracker::Mechanize->new;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Data::Channel',
    ],
    mech => $mech,
);

my $orddetails  = $framework->flow_db__fulfilment__create_order(
    channel => $framework->channel,
    products => 3,
);

my $order = $orddetails->{order_object};

$framework->login_with_permissions({
    dept => 'Distribution Management',
    perms => { $AUTHORISATION_LEVEL__OPERATOR => [
        'Customer Care/Order Search',
        'Customer Care/Customer Search',
    ]}
});

$order->customer->update({
    category_id => $CUSTOMER_CATEGORY__PRESS_CONTACT
});

my $results = $framework->flow_mech__customercare__order_search_results({search_term => $order->order_nr, search_type => 'order_number'})->mech->as_data->{results};

is($order->customer->category->id, $CUSTOMER_CATEGORY__PRESS_CONTACT, "Correct customer category is set");
is($results->[0]->{Category}, $order->customer->category->category, "Correct customer category is listed");

note "Testing that submitting an order search based upon telephone number with a + prefix does not crash XT";
$framework->flow_mech__customercare__order_search_results( {
    search_term => '+1231412',
    search_type => 'telephone_number'
});

done_testing();

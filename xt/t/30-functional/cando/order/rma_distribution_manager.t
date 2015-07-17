#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 DESCRIPTION

This tests that when Logged in as a user for the Distribution Management
department you can Create Returns but not get the option to send Emails to the
Customer.

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => ['$distribution_centre'];
use Test::XTracker::Mechanize;
use XTracker::Constants::FromDB qw/
  :authorisation_level
/;

# go get some pids relevant to the db I'm using - channel is for test context
my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
});

foreach my $item (@{$pids}) {
    Test::XTracker::Data->ensure_variants_stock($item->{pid});
}

my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
    pids => $pids,
    attrs => [
        { price => 250.00 },
        { price => 100.00 },
    ],
});

my $order_nr = $order->order_nr;
ok(my $shipment = $order->shipments->first, "Sanity check: the order has a shipment");

note "Order Nr: $order_nr";


Test::XTracker::Data->grant_permissions(
    'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );
Test::XTracker::Data->set_department('it.god', 'Distribution Management');

my $mech = Test::XTracker::Mechanize->new;
$mech->do_login;
$mech->force_datalite(1);

my $return;

$shipment->shipment_email_logs->delete;
$mech->order_nr($order_nr);
$mech->test_create_rma($shipment);
cmp_ok( $shipment->discard_changes->shipment_email_logs->count(), '==', 0, "No Emails were Logged" );

done_testing;

#!/usr/bin/env perl

use NAP::policy qw/test/;

=head1 NAME

test.xtracker.carrier.t - Carrier tests

=head1 DESCRIPTION

#TAGS carrier ups dhl shouldbeunit

=cut


use FindBin::libs;

use XTracker::Constants::FromDB     qw( :channel );

# this forces connections to the same DB & forces the
# use of the same config files as the Test Harness
use Test::XTracker::Data;
use Test::XTracker::Carrier;
use XTracker::Config::Local       qw( config_var );

my $dc_name = config_var( 'DistributionCentre', 'name' );
note "TESTING IN ".$dc_name;

use_ok('Test::XTracker::Carrier');

# lovely, evil, global variables
my (
    @expected_methods,
    $carrier_test,
    $dhl_manifest,
    $dhl_shipment,
    $dhl_shipment_id,
    $manifest,
    $manifest_id,
    $unknown_shipment,
    $ups_manifest,
    $ups_shipment,
    $ups_shipment_id,
);

# these are functions that NAP::Carrier and NAP::Carrier::* should support
@expected_methods = qw<
    any_manifest
    dhl_manifest
    dhl_shipment
    schema
    unknown_shipment
    ups_manifest
    ups_shipment
>;

# make sure the generic object supports our methods
can_ok('Test::XTracker::Carrier', @expected_methods);

# something to give us useful objects/records to test with
$carrier_test = Test::XTracker::Carrier->new;
isa_ok($carrier_test, 'Test::XTracker::Carrier');


# store values we like, so we're not forever looking then up in the DB
$ups_shipment    = $carrier_test->ups_shipment;
$dhl_shipment    = $carrier_test->dhl_shipment;
$ups_shipment_id = $carrier_test->ups_shipment->id      if ( defined $carrier_test->ups_shipment );
$dhl_shipment_id = $carrier_test->dhl_shipment->id      if ( defined $carrier_test->dhl_shipment );
$manifest        = $carrier_test->any_manifest;
$manifest_id     = $carrier_test->any_manifest->id;

# make sure they look sane (defined, correct carrier)
isa_ok($ups_shipment, 'XTracker::Schema::Result::Public::Shipment')     if ( defined $ups_shipment );
isa_ok($dhl_shipment, 'XTracker::Schema::Result::Public::Shipment')     if ( defined $dhl_shipment );
isa_ok($manifest, 'XTracker::Schema::Result::Public::Manifest');

is($ups_shipment->shipping_account->carrier->name, 'UPS', '$ups_shipment is UPS')                           if ( defined $ups_shipment );
like($dhl_shipment->shipping_account->carrier->name, qr{\ADHL\s.+\z}, '$dhl_shipment is DHL-<something>')   if ( defined $dhl_shipment );

ok(defined($ups_shipment_id), '$ups_shipment_id is defined')        if ( defined $ups_shipment );
ok(defined($dhl_shipment_id), '$dhl_shipment_id is defined')        if ( defined $dhl_shipment );
ok(defined($manifest_id), '$manifest_id is defined');

SKIP: {
    skip "DHL Tests can only be done in DC1 Environment",1      if ( $dc_name ne "DC1" );

    # make sure we can fetch a shipment by specific DHL carrier type
    $dhl_shipment    = $carrier_test->dhl_shipment('DHL Express');
    is($dhl_shipment->shipping_account->carrier->name, 'DHL Express', '$dhl_shipment is DHL Express');

    # make sure we can fetch a manifest by specific DHL carrier type
    $dhl_manifest    = $carrier_test->dhl_manifest('DHL Express');
    is($dhl_manifest->carrier->name, 'DHL Express', '$dhl_manifest is DHL Express');
}

SKIP: {
    skip "UPS Tests can only be done in DC2 Environment",1      if ( $dc_name ne "DC2" );

    # make sure we can fetch a manifest by specific UPS carrier type
    $ups_manifest    = $carrier_test->ups_manifest;
    is($ups_manifest->carrier->name, 'UPS', '$ups_manifest is UPS');
}

# make sure we can get shipment(s) where the carrier is unknown
$unknown_shipment = $carrier_test->unknown_shipment;
is($unknown_shipment->carrier->name, 'Unknown', '$unknown_manifest is Unknown');

done_testing;

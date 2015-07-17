#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XT::AssertDBRecords;
use Test::XTracker::Data;

my $path = 't/data/'. Test::XTracker::Data::whatami();

my $TABLES = [ qw/
    Public::ShippingCharge
    Public::ShippingAccount
/ ];
# FIXME: taken out cos we haven't gotten to the stage that the schema is
# FIXME: populated
#    Shipping::Zone
#    Shipping::Option

if ($ENV{TEST_ASSERTRECORDS}) {
    $TABLES = [ "$ENV{TEST_ASSERTRECORDS}" ];
}

foreach my $table (@{$TABLES}) {
    note "Asserting (something about) $table";
    Test::XT::AssertDBRecords->run(
        $path,
        Test::XTracker::Data->get_schema,
        $table,
    );
}

done_testing();


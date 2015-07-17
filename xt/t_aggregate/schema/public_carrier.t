#!/usr/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

# load the module that provides all of the common test functionality
use FindBin::libs;
use Test::Most;
use Test::XTracker::Data;
use SchemaTest;


my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::Carrier',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                tracking_uri
                last_pickup_daytime
            ]
        ],

        relations => [
            qw[
                carrier_box_weights
                audit_recents
                manifests
                shipping_accounts
                returns_charges
            ]
        ],

        custom => [
            qw[
                tracking_uri
                last_pickup_daytime
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();

##########################
# Test some custom methods


note "Make sure the inflated datatypes are ok";
my $schema = Test::XTracker::Data->get_schema;
my $carrier_rs = $schema->resultset("Public::Carrier");

# pick any one - they should all have a valid time in there
my $carrier_row = $carrier_rs->first;

my $last_pickup_daytime = $carrier_row->last_pickup_daytime;
isa_ok(
    $last_pickup_daytime,
    "DateTime::Duration",
    "Column value of last_pickup_daytime isa Duration",
);

done_testing();

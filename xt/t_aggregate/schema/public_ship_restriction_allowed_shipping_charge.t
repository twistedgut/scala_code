#!/usr/bin/perl
use NAP::policy qw/test/;

use List::Util qw/ first /;

# load the module that provides all of the common test functionality
use FindBin::libs;

use Test::XTracker::Data;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::ShipRestrictionAllowedShippingCharge',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                ship_restriction_id
                shipping_charge_id
            ]
        ],

        relations => [
            qw[
                ship_restriction
                shipping_charge
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();

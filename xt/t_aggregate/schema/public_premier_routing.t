#!/usr/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

# load the module that provides all of the common test functionality
use FindBin::libs;

use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::PremierRouting',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                description
                code
                earliest_delivery_daytime
                latest_delivery_daytime
            ]
        ],

        relations => [
            qw[
                shipments
                shipping_charges
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                find_code
            ]
        ],
    }
);

$schematest->run_tests();

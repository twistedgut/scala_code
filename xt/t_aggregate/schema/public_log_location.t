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
        moniker   => 'Public::LogLocation',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                variant_id
                location_id
                date
                operator_id
                channel_id
            ]
        ],

        relations => [
            qw[
                location
                channel
                product_variant
                voucher_variant
                operator
            ]
        ],

        custom => [
            qw[
                variant
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();

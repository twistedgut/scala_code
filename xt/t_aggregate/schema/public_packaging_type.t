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
        moniker   => 'Public::PackagingType',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                sku
                name
            ]
        ],

        relations => [
            qw[
                pre_orders
                packaging_attributes
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                hash
            ]
        ],
    }
);

$schematest->run_tests();

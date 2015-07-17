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
        moniker   => 'Public::StockCountVariant',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                variant_id
                location_id
                stock_count_category_id
                last_count
            ]
        ],

        relations => [
            qw[
                variant
                location
                stock_count_category
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

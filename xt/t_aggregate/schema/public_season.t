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
        moniker   => 'Public::Season',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                season
                season_year
                season_code
                active
            ]
        ],

        relations => [
            qw[
                purchase_orders
                season_conversion_rates
                products
                promotion_detail_seasons
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                drop_down_options
                season_list
            ]
        ],
    }
);

$schematest->run_tests();

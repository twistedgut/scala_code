#!/usr/bin/perl
use strict;
use warnings;

# load the module that provides all of the common test functionality
use FindBin::libs;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::ReservationType',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                type
                sort_order
                is_active
            ]
        ],

        relations => [
            qw[
                reservations
                pre_orders
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                list_by_sort_order
                list_alphabetically
            ]
        ],
    }
);

$schematest->run_tests();

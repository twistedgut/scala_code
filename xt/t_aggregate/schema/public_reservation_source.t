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
        moniker   => 'Public::ReservationSource',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                source
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
                active_list_by_sort_order
                list_alphabetically
            ]
        ],
    }
);

$schematest->run_tests();

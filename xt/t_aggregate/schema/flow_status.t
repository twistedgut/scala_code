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
        moniker   => 'Flow::Status',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                type_id
                is_initial
            ]
        ],

        relations => [
            qw[
                next_status
                prev_status
                type
                list_next_status
                location_allowed_statuses
                quantities
                rtv_quantities
            ]
        ],

        custom => [
            qw[
                is_valid_next
                iws_name
            ]
        ],

        resultsets => [
            qw[
                all_of_type_rs
                find_by_iws_name
            ]
        ],
    }
);

$schematest->run_tests();

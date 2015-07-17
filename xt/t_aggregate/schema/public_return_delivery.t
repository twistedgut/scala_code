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
        moniker   => 'Public::ReturnDelivery',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                confirmed
                date_confirmed
                date_created
                created_by
                operator_id
            ]
        ],

        relations => [
            qw[
                return_arrivals
                operator
                created_by
            ]
        ],

        custom => [
            qw[
                add_arrival
                total_packages
                confirm
            ]
        ],

        resultsets => [
            qw[
                search_by_date
            ]
        ],
    }
);

$schematest->run_tests();

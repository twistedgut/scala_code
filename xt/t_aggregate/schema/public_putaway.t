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
        moniker   => 'Public::Putaway',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                stock_process_id
                location_id
                quantity
                timestamp
                complete
                last_updated
                id
            ]
        ],

        relations => [
            qw[
                location
                stock_process
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                incomplete
                total_quantity
            ]
        ],
    }
);

$schematest->run_tests();

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
        moniker   => 'Flow::NextStatus',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                current_status_id
                next_status_id
            ]
        ],

        relations => [
            qw[
                current_status
                next_status
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

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
        moniker   => 'Public::CustomerNote',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                customer_id
                note
                note_type_id
                operator_id
                date
            ]
        ],

        relations => [
            qw[
                note_type
                customer
                operator
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


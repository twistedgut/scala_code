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
        moniker   => 'Public::DblSubmitToken',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
            ]
        ],

        relations => [
            qw[
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                mark_as_used
            ]
        ],
    }
);

$schematest->run_tests();

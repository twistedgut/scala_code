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
        moniker   => 'Promotion::CouponGeneration',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                idx
                action
                description
            ]
        ],

        relations => [
            qw[
                details
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                action_list
            ]
        ],
    }
);

$schematest->run_tests();

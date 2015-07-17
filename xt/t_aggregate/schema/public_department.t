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
        moniker   => 'Public::Department',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                department
            ]
        ],

        relations => [
            qw[
                operators
                correspondence_templates
                renumeration_reasons
            ]
        ],

        custom => [
            qw[
                is_in_customer_care_group
            ]
        ],

        resultsets => [
            qw[
                customer_care_group
            ]
        ],
    }
);

$schematest->run_tests();


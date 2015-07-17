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
        moniker   => 'Promotion::CustomerCustomerGroup',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                customer_id
                customergroup_id
                website_id
                created
                created_by
                modified
                modified_by
            ]
        ],

        relations => [
            qw[
                customergroup
                website
                created
                modified
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                get_by_customer_and_group
                get_by_join_data
            ]
        ],
    }
);

$schematest->run_tests();

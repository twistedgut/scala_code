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
        moniker   => 'Fraud::ArchivedList',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                list_type_id
                name
                description
                change_log_id
                created
                created_by_operator_id
                expired
                expired_by_operator_id
            ]
        ],

        relations => [
            qw[
                list_type
                archived_list_items
                live_lists
                list_items
                change_log
                created_by_operator
                expired_by_operator
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

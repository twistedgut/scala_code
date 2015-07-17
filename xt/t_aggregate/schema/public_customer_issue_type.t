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
        moniker   => 'Public::CustomerIssueType',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                group_id
                description
                pws_reason
                category_id
                display_sequence
                enabled
            ]
        ],

        relations => [
            qw[
                cancelled_items
                category
                return_items
                customer_issue_type_group
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                return_reason_from_pws_code
                return_reasons
                cancellation_reasons
                return_reasons_for_rma_pages
            ]
        ],
    }
);

$schematest->run_tests();


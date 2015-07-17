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
        moniker   => 'Public::RenumerationReason',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                renumeration_reason_type_id
                reason
                department_id
                enabled
            ]
        ],

        relations => [
            qw[
                department
                renumeration_reason_type
                renumerations
                bulk_reimbursements
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                get_reasons_for_type
                get_compensation_reasons
                order_by_reason
                order_by_reason_desc
                enabled_only
            ]
        ],
    }
);

$schematest->run_tests();

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
        moniker   => 'Public::BulkReimbursement',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                created_timestamp
                operator_id
                channel_id
                bulk_reimbursement_status_id
                credit_amount
                reason
                send_email
                email_subject
                email_message
                renumeration_reason_id
            ]
        ],

        relations => [
            qw[
                bulk_reimbursement_status
                channel
                link_bulk_reimbursement__orders
                renumeration_reason
                operator
            ]
        ],

        custom => [
            qw[
            ],
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();

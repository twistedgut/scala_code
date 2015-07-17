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
        moniker   => 'DBAdmin::BackFillJob',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                description
                back_fill_job_status_id
                back_fill_table_name
                back_fill_primary_key_field
                update_set
                resultset_select
                resultset_from
                resultset_where
                resultset_order_by
                max_rows_to_update
                max_jobs_to_create
                time_to_start_back_fill
                contact_email_address
                created
            ]
        ],

        relations => [
            qw[
                back_fill_job_status
                log_back_fill_job_runs
                log_back_fill_job_statuses
            ]
        ],

        custom => [
            qw[
                is_cancelled
                is_completed
                is_in_progress
                is_new
                is_on_hold
                job_ok_to_run
                has_start_time_passed
                update_status
                mark_as_completed
                mark_as_in_progress
                log_outcome_and_set_status_after_running_job
                send_email_to_contact_address
            ]
        ],

        resultsets => [
            qw[
                order_by_id
                get_runnable_jobs
            ]
        ],
    }
);

$schematest->run_tests();

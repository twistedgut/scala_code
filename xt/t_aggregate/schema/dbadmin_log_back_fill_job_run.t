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
        moniker   => 'DBAdmin::LogBackFillJobRun',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                back_fill_job_id
                number_of_rows_updated
                error_was_thrown
                start_time
                finish_time
                operator_id
            ]
        ],

        relations => [
            qw[
                back_fill_job
                operator
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                total_rows_updated
                with_no_errors
                with_no_errors_rs
            ]
        ],
    }
);

$schematest->run_tests();

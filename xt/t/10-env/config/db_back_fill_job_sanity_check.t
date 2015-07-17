#!/usr/bin/env perl

use NAP::policy     qw( test );

=head1 NAME

db_back_fill_job_sanity_check.t

=head1 DESCRIPTION

This tests any records in the 'dbadmin.back_fill_job' table that they can be processed
properly by the 'XT::DB::BackFill' class.

If any fail then 'BAIL_OUT' will be used to tell the Harness to stop as a Release
should not be cut if any of these fail.

The records in the 'dbadmin.back_fill_job' table at the time of the run will be any that
have been created as part of the DB Patches for the Release (or in the 9999.99 directory).
That table will NOT be part of those in the 'Test::XT::BlankDB' class and so it won't
be holding every Back-Fill Job ever created, it will only hold those for the current/next
release and so only those get Tested. The reason for not testing past Jobs is because
they would have already been tested when they were first created and part of a Release.

=cut

use Test::XTracker::Data;

use XT::DB::BackFill;


my $schema = Test::XTracker::Data->get_schema();

# going to change some of the Back-Fill Job records so
# start a Transaction that will be Rolled back at the end
$schema->txn_begin;

# update the Time to Start time on each record
# to now so that all records can be Tested
$schema->resultset('DBAdmin::BackFillJob')
        ->update( { time_to_start_back_fill => $schema->db_now } );

my $back_fill_job_rs = $schema->resultset('DBAdmin::BackFillJob')
                                ->get_runnable_jobs;

# if no records then SKIP the test
my $number_of_jobs = $back_fill_job_rs->count;
SKIP: {
    skip "No 'dbadmin.back_fill_job' records to Test", 1        if ( !$number_of_jobs );

    note "Going to Test ${number_of_jobs} Back-Fill Jobs";

    my @jobs = $back_fill_job_rs->reset->all;
    foreach my $job_rec ( @jobs ) {
        my $job_desc = '(' . $job_rec->id . ') - ' . $job_rec->name;

        my $ok = subtest "Back-Fill Job: '${job_desc}'" => sub {
            my $back_fill_obj;
            lives_ok {
                $back_fill_obj = XT::DB::BackFill->new( { back_fill_job => $job_rec } );
            } "can instantiate an instance of 'XT::DB::BackFill'";
            isa_ok( $back_fill_obj, 'XT::DB::BackFill' );

            lives_ok {
                my $sth = $back_fill_obj->get_statement_handle_for_update;
            } "can get a Statment Handle for the UPDATE SQL";

            lives_ok {
                my $rec_count = $back_fill_obj->run_job;
            } "can call method 'run_job'";
        };

        if ( !$ok ) {
            fail(
                "ERROR - Back-Fill Job: '${job_desc}' FAILED - NO RELEASE SHOULD BE CUT UNTIL IT'S BEEN FIXED"
            );
            diag <<EOM
##############################################

ERROR - Back-Fill Job: '${job_desc}' FAILED

NO RELEASE SHOULD BE CUT UNTIL IT'S BEEN FIXED

##############################################
EOM
;
        }
    }
};

# undo the changes made
$schema->txn_rollback;

done_testing;


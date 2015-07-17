package Test::XTracker::Schema::Result::DBAdmin::BackFillJob;

use NAP::policy     qw( test );
use parent 'NAP::Test::Class';

=head1 NAME

Test::XTracker::Schema::Result::DBAdmin::BackFillJob

=head1 DESCRIPTION

Tests various Methods & Result Set Methods for 'XTracker::Schema::Result::DBAdmin::BackFillJob'

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::DBAdminBackFillJob;
use Test::XT::Data;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :dbadmin_back_fill_job_status );

use XT::DB::BackFill;

use Mock::Quick;


sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;

    my $data = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::DBAdminBackFillJob',
        ],
    );
    $self->{data} = $data;

    # prevent any existing Jobs from interfering
    Test::XTracker::Data::DBAdminBackFillJob->cancel_existing_back_fill_jobs;
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}


=head1 TESTS

=head2 test_is_status_methods

Tests the various 'is_' methods that are used to check what
Status the Back Fill Job record is set to.

=cut

sub test_is_status_methods : Tests {
    my $self = shift;

    # get a Back Fill Job record
    my $back_fill_job = $self->_data->back_fill_job;

    my $status_rs = $self->rs('DBAdmin::BackFillJobStatus');

    # list of Statuses and their 'is_' method
    my %status_to_method = (
        $DBADMIN_BACK_FILL_JOB_STATUS__NEW          => 'is_new',
        $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS  => 'is_in_progress',
        $DBADMIN_BACK_FILL_JOB_STATUS__ON_HOLD      => 'is_on_hold',
        $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED    => 'is_completed',
        $DBADMIN_BACK_FILL_JOB_STATUS__CANCELLED    => 'is_cancelled',
    );

    # get all the Methods and set their expected return value to be FALSE
    my %all_methods = map { $_ => 0 } values %status_to_method;

    while ( my ( $status_id, $is_method ) = each %status_to_method ) {
        my $status_rec = $status_rs->find( $status_id );
        $back_fill_job->discard_changes->update( { back_fill_job_status_id => $status_id } );
        my $got = $back_fill_job->$is_method;
        cmp_ok( $got, '==', 1, "When Status is '" . $status_rec->status . "' the method '${is_method}' returns TRUE" );

        # now check that all the other Methods return FALSE for this Status
        delete $all_methods{ $is_method };      # delete this Statuses Method
        my %got_other_methods = map { $_ => $back_fill_job->$_ } keys %all_methods;
        cmp_deeply( \%got_other_methods, \%all_methods, "and all other Methods return FALSE" )
                        or diag "ERROR - Other Methods didn't return FALSE:\n" .
                                "Got: " . p( %got_other_methods ) . "\n" .
                                "Expected: " . p( %all_methods );

        # now put back in this method for the next test
        $all_methods{ $is_method } = 0;
    }
}

=head2 test_job_ok_to_run

Tests the 'job_ok_to_run' method which checks whether it is ok to run the Back-fill Job.

=cut

sub test_job_ok_to_run : Tests {
    my $self = shift;

    # get a Back-fill Job record, setting the
    # time that Back-fill Job can start to now
    my $db_now = $self->schema->db_now();
    $self->_data->time_to_start_back_fill( $db_now );
    my $back_fill_job = $self->_data->back_fill_job;

    # get all the Statuses split between allowed
    # to run and not allowed to run the job
    my $statuses = Test::XTracker::Data->get_allowed_notallowed_statuses( 'DBAdmin::BackFillJobStatus', {
        allow => [
            $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
            $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
        ],
    } );

    note "Check Statuses that shouldn't allow the Job to be Run";
    foreach my $status_rec ( @{ $statuses->{not_allowed} } ) {
        my $status = $status_rec->status;
        $back_fill_job->update( { back_fill_job_status_id => $status_rec->id } );
        my $got = $back_fill_job->discard_changes->job_ok_to_run;
        ok( !$got, "'job_ok_to_run' returns FALSE when Status is '${status}'" );
    }

    note "Check Statuses that should allow the Job to be Run";
    foreach my $status_rec ( @{ $statuses->{allowed} } ) {
        my $status = $status_rec->status;
        $back_fill_job->update( { back_fill_job_status_id => $status_rec->id } );
        my $got = $back_fill_job->discard_changes->job_ok_to_run;
        ok( $got, "'job_ok_to_run' returns TRUE when Status is '${status}'" );
    }

    note "Set the time that the Job can start to be 1 Day from now with an Allowed Status";
    $back_fill_job->update( { time_to_start_back_fill => $db_now->clone->add( days => 1 ) } );
    my $got = $back_fill_job->discard_changes->job_ok_to_run;
    ok( !$got, "'job_ok_to_run' returns FALSE when Status is Allowed but it's too soon to run the Job" );
}

=head2 test_mark_as_methods

Tests the 'mark_as_*' methods to make sure the Status is
Updated and Logged.

=cut

sub test_mark_as_methods : Tests {
    my $self = shift;

    # get a Back Fill Job record at 'New' Status
    $self->_data->back_fill_job_status_id( $DBADMIN_BACK_FILL_JOB_STATUS__NEW );
    my $back_fill_job = $self->_data->back_fill_job;

    my %tests = (
        "Mark as Completed" => {
            setup => {
                mark_method => 'mark_as_completed',
                is_method   => 'is_completed',
            },
            expect => {
                status_id => $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED,
            },
        },
        "Mark as In Progress" => {
            setup => {
                mark_method => 'mark_as_in_progress',
                is_method   => 'is_in_progress',
            },
            expect => {
                status_id => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "TEST: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # delete any Status Logs
        $back_fill_job->discard_changes
                        ->log_back_fill_job_statuses
                            ->delete;

        my $mark_as_method = $setup->{mark_method};
        my $is_method      = $setup->{is_method};

        # call the Method to set the Status of the Back Fill Job record
        $back_fill_job->$mark_as_method( $APPLICATION_OPERATOR_ID );
        $back_fill_job->discard_changes;

        cmp_ok( $back_fill_job->$is_method, '==', 1, "'${is_method}' returns TRUE" );
        cmp_ok( $back_fill_job->log_back_fill_job_statuses->count, '==', 1, "One Status Log has been Created" );
        my $log = $back_fill_job->log_back_fill_job_statuses->first;
        cmp_ok( $log->back_fill_job_status_id, '==', $expect->{status_id},
                        "and the Log record created is for the correct Status Change" );
    }
}

=head2 test_get_runnable_jobs_resultset

Tests the 'get_runnable_jobs' Result Set method that returns Back Fill Jobs
that are available to be Run.

=cut

sub test_get_runnable_jobs_resultset : Tests {
    my $self = shift;

    # get the current time from the DB
    my $time_now = $self->schema->db_now();

    # arguments used to create the different Jobs, Statuses 'New'
    # and 'In Progress' should be returned but only if the time
    # to start the Back Fill Job has passed
    my @job_args = (
        {
            name                    => 'New - Should be Returned',
            back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
            expect_to_be_returned   => 1,
        },
        {
            name                    => 'New - Should NOT be Returned',
            # set the Start Time to be a day from now so it shouldn't be returned
            back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
            time_to_start_back_fill => $time_now->clone->add( days => 1 ),
        },
        {
            name                    => 'In Progress - Should be Returned',
            back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
            expect_to_be_returned   => 1,
        },
        {
            name                    => 'In Progress - Should NOT be Returned',
            back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
            time_to_start_back_fill => $time_now->clone->add( days => 1 ),
        },
        { name => 'On Hold',   back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__ON_HOLD },
        { name => 'Completed', back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED },
        { name => 'Cancelled', back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__CANCELLED },
    );

    # split the above Job arguments between those that are
    # expected to be returned by the method and those that
    # aren't and also create the Back Fill Job records
    my @expected_jobs     = map {
        Test::XTracker::Data::DBAdminBackFillJob->create_one_back_fill_job( $_ )
    } grep { $_->{expect_to_be_returned} } @job_args;
    my @not_expected_jobs = map {
        Test::XTracker::Data::DBAdminBackFillJob->create_one_back_fill_job( $_ )
    } grep { !$_->{expect_to_be_returned} } @job_args;

    my @got_jobs = $self->rs('DBAdmin::BackFillJob')->get_runnable_jobs->order_by_id->all;

    my @got_ids    = map { $_->id } @got_jobs;
    my @expect_ids = map { $_->id } @expected_jobs;
    cmp_deeply( \@got_ids, \@expect_ids, "'get_runnable_jobs' returned the Expected Jobs" )
                        or diag "ERROR - didn't return the Expected Jobs:\n" .
                                "Got: " . p( @got_ids ) . "\n" .
                                "Expected: " . p( @expect_ids );
}

=head2 test_log_outcome_and_set_status_after_running_job

Tests the 'log_outcome_and_set_status_after_running_job' method
that will create 'log_back_fill_job_run' records and update the
Status of the 'back_fill_job' record.

=cut

sub test_log_outcome_and_set_status_after_running_job : Tests {
    my $self = shift;

    # get a Back Fill Job record
    my $back_fill_job_rec = $self->_data->back_fill_job;

    my %tests = (
        "Status gets set to 'In Progress'" => {
            setup => {
                records_updated => 365,
            },
            expect => {
                status_id          => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
                status_log_created => 1,
            },
        },
        "Status gets set to 'Completed'" => {
            setup => {
                records_updated => 0,
            },
            expect => {
                status_id          => $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED,
                status_log_created => 1,
            },
        },
        "Status gets set to 'Completed' from 'In Progress'" => {
            setup => {
                records_updated => 0,
                status_id       => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
            },
            expect => {
                status_id          => $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED,
                status_log_created => 1,
            },
        },
        "Subsequent runs starting at 'In Progress' don't keep Logging 'In Progress' Status" => {
            setup => {
                records_updated => 124,
                status_id       => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
            },
            expect => {
                status_id          => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
                status_log_created => 0,
            },
        },
        "Log when Error Thrown and Status gets set to 'In Progress'" => {
            setup => {
                records_updated => 0,
                throw_error     => 1,
            },
            expect => {
                status_id          => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
                status_log_created => 1,
                error_thrown_flag  => 1,
            },
        },
        "Log when Error Thrown and Status is already set to 'In Progress'" => {
            setup => {
                records_updated => 0,
                status_id       => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
                throw_error     => 1,
            },
            expect => {
                status_id          => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
                status_log_created => 0,
                error_thrown_flag  => 1,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "TEST: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        $back_fill_job_rec->discard_changes;
        $back_fill_job_rec->log_back_fill_job_statuses->delete;
        $back_fill_job_rec->log_back_fill_job_runs->delete;

        $back_fill_job_rec->update( {
            back_fill_job_status_id => $setup->{status_id} //
                                        $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
        } );

        my $records_updated = $setup->{records_updated};

        my $backfill_obj = XT::DB::BackFill->new( {
            back_fill_job => $back_fill_job_rec,
        } );

        # set-up the Back Fill Job object for the Test
        $backfill_obj->_was_run(1);
        $backfill_obj->_error_was_thrown(1)     if ( $setup->{throw_error} );
        $backfill_obj->set_start_time;
        $backfill_obj->set_finish_time;
        $backfill_obj->_set_record_count( $records_updated );

        $back_fill_job_rec->log_outcome_and_set_status_after_running_job(
            $backfill_obj,
            $APPLICATION_OPERATOR_ID,
        );
        $back_fill_job_rec->discard_changes;

        cmp_ok( $back_fill_job_rec->back_fill_job_status_id, '==', $expect->{status_id},
                        "Back Fill Job record Status as Expected" );
        cmp_ok( $back_fill_job_rec->log_back_fill_job_statuses->count, '==', $expect->{status_log_created},
                        "a Back Fill Job Status Log record created" );
        cmp_ok( $back_fill_job_rec->log_back_fill_job_runs->count, '==', 1,
                        "a Back Fill Job Run Log record created" );
        my $log = $back_fill_job_rec->log_back_fill_job_runs->first;
        cmp_ok( $log->number_of_rows_updated, '==', $records_updated,
                        "the Run Log 'number_of_rows_updated' value is as Expected" );
        cmp_ok( $log->error_was_thrown, '==', $expect->{error_thrown_flag} // 0,
                        "and Run Log 'error_was_thrown' value is as Expected" );
    }
}

=head2 test_log_back_fill_job_run_result_set_methods

Tests Result-Set Methods on the 'DBAdmin::LogBackFillJobRun' class.

=cut

sub test_log_back_fill_job_run_result_set_methods : Tests {
    my $self = shift;

    # get a Back Fill Job record
    my $back_fill_job = $self->_data->back_fill_job;

    # delete any log records that may exist
    $back_fill_job->log_back_fill_job_runs->delete;

    # get the current time from the DB
    my $db_now = $self->schema->db_now;

    # test the 'total_rows_updated' method with NO rows
    my $got = $back_fill_job->log_back_fill_job_runs->total_rows_updated;
    cmp_ok( $got, '==', 0, "Result-Set Method 'total_rows_updated' returns ZERO when there are NO Log records" );

    my @log_create_args = (
        {
            number_of_rows_updated => 3,
            error_was_thrown       => 0,
            start_time             => $db_now->clone,
            finish_time            => $db_now->clone,
            operator_id            => $APPLICATION_OPERATOR_ID,
        },
        {
            number_of_rows_updated => 0,
            error_was_thrown       => 1,
            start_time             => $db_now->clone,
            finish_time            => $db_now->clone,
            operator_id            => $APPLICATION_OPERATOR_ID,
        },
        {
            number_of_rows_updated => 14,
            error_was_thrown       => 0,
            start_time             => $db_now->clone,
            finish_time            => $db_now->clone,
            operator_id            => $APPLICATION_OPERATOR_ID,
        },
    );
    note "Create a few 'log_back_fill_job_run' records";
    foreach my $create_args ( @log_create_args ) {
        $back_fill_job->create_related( 'log_back_fill_job_runs', $create_args );
    }

    # test the 'total_rows_updated' method
    $got = $back_fill_job->log_back_fill_job_runs->total_rows_updated;
    cmp_ok( $got, '==', 17, "Result-Set Method 'total_rows_updated' returns the Expected Total" );

    # test the 'with_no_errors' method
    $got = $back_fill_job->log_back_fill_job_runs->with_no_errors->count;
    cmp_ok( $got, '==', 2, "Result-Set Method 'with_no_errors' returns as Expected" );

    # test the 'with_no_errors_rs' method
    $got = $back_fill_job->log_back_fill_job_runs->with_no_errors_rs->count;
    cmp_ok( $got, '==', 2, "Result-Set Method 'with_no_errors_rs' returns as Expected" );


    note "check the return values of 'with_no_errors' & 'with_no_errors_rs' when called in Array context";

    ( $got ) = $back_fill_job->log_back_fill_job_runs->with_no_errors;
    isa_ok( $got, 'XTracker::Schema::Result::DBAdmin::LogBackFillJobRun',
                "'with_no_errors' called in Array context returns a Result Object" );

    ( $got ) = $back_fill_job->log_back_fill_job_runs->with_no_errors_rs;
    isa_ok( $got, 'XTracker::Schema::ResultSet::DBAdmin::LogBackFillJobRun',
                "'with_no_errors_rs' called in Array context returns a ResultSet Object" );
}

=head2 test_send_email_to_contact_address

Tests the 'send_email_to_contact_address' method that sends an Email to the
Contact Email Address specified on the 'back_fill_job' record.

This uses the following template to build the email:

    email/internal/db_back_fill_job_alert.tt

=cut

sub test_send_email_to_contact_address : Tests {
    my $self = shift;

    # get a Back Fill Job record
    my $back_fill_job = $self->_data->back_fill_job;

    # get the Job Id & Job Name to make easy to use in regex's
    my $job_id   = $back_fill_job->id;
    my $job_name = $back_fill_job->name;

    $back_fill_job->update( {
        contact_email_address   => 'test@net-a-porter.com',
        back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED,
    } );

    # this value will be used in the following tests,
    # the value is just picked out of the air
    my $number_of_rows_updated = 2343;

    # get the current time from the DB
    my $db_now = $self->schema->db_now();

    # create a 'log_back_fill_job_run' record for the Job
    $back_fill_job->create_related( 'log_back_fill_job_runs', {
        number_of_rows_updated => $number_of_rows_updated,
        error_was_thrown       => 0,
        start_time             => $db_now->clone,
        finish_time            => $db_now->clone,
        operator_id            => $APPLICATION_OPERATOR_ID,
    } );

    my $send_email_to_die = 0;
    my %email_params;
    my $mock_email = qtakeover 'XTracker::EmailFunctions' => (
        send_email => sub {
            my @params = @_;

            %email_params = (
                from        => $params[0],
                replyto     => $params[1],
                to          => $params[2],
                subject     => $params[3],
                body        => $params[4],
                type        => $params[5],
                attachments => $params[6],
                email_args  => $params[7],
            );

            die "TEST TOLD ME TO DIE\n"     if ( $send_email_to_die );

            return 1;
        },
    );

    my %tests = (
        "Send an Email with a Subject Suffix" => {
            setup => {
                subject_suffix => 'Job is Complete',
            },
            expect => {
                to      => 'test@net-a-porter.com',
                subject => '[DB Back-Fill Alert] Back-Fill Job Id: ' . $job_id . ', Job is Complete',
                body    => qr/
                    Job\sId.*${job_id}.*
                    Job\sName.*\Q${job_name}\E.*
                    Status.*Completed.*
                    Records\sUpdated.*${number_of_rows_updated}.*
                    Job\sRuns\sDone.*1
                /xis,
            },
        },
        "Send an Email without a Subject Suffix" => {
            setup  => { },
            expect => {
                to      => 'test@net-a-porter.com',
                subject => '[DB Back-Fill Alert] Back-Fill Job Id: ' . $job_id,
                body    => qr/
                    Job\sId.*${job_id}.*
                    Job\sName.*\Q${job_name}\E.*
                    Status.*Completed.*
                    Records\sUpdated.*${number_of_rows_updated}.*
                    Job\sRuns\sDone.*1
                /xis,
            },
        },
        "Send an Email with the 'extra_information' argument" => {
            setup => {
                subject_suffix => 'Job had an Error',
                args => {
                    extra_information => 'this should be shown in the email body',
                },
            },
            expect => {
                to      => 'test@net-a-porter.com',
                subject => '[DB Back-Fill Alert] Back-Fill Job Id: ' . $job_id . ', Job had an Error',
                body    => qr/
                    Job\sId.*${job_id}.*
                    Job\sName.*\Q${job_name}\E.*
                    Status.*Completed.*
                    Records\sUpdated.*${number_of_rows_updated}.*
                    Job\sRuns\sDone.*1.*
                    \Qthis should be shown in the email body\E
                /xis,
            },
        },
        "Send an Email When 'send_email' die's, 'send_email_to_contact_address' should NOT die" => {
            setup => {
                tell_send_email_to_die => 1,
            },
            expect => {
                to      => 'test@net-a-porter.com',
                subject => '[DB Back-Fill Alert] Back-Fill Job Id: ' . $job_id,
                body    => qr/
                    Job\sId.*${job_id}.*
                    Job\sName.*\Q${job_name}\E.*
                    Status.*Completed.*
                    Records\sUpdated.*${number_of_rows_updated}.*
                    Job\sRuns\sDone.*1
                /xis,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "TEST: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # reset some data for the 'send_email' function
        %email_params      = ();
        $send_email_to_die = $setup->{tell_send_email_to_die} // 0;

        my $subject_suffix = $setup->{subject_suffix};

        # send the Email
        lives_ok {
            $back_fill_job->send_email_to_contact_address( $subject_suffix, $setup->{args} );
        } "the Method 'send_email_to_contact_address' lives when called";

        # check what got passed to 'send_email'
        is( $email_params{to}, $expect->{to}, "To Address is as Expected" );
        is( $email_params{subject}, $expect->{subject}, "Subject is as Expected" );
        like( $email_params{body}, $expect->{body}, "Body is as Expected" );
    }


    # un-mock
    $mock_email->restore('send_email');
    $mock_email = undef;
}

#-------------------------------------------------------------------

sub _data {
    my $self = shift;
    return $self->{data};
}


package Test::XTracker::Script::DB::CreateBackFillJob;
use NAP::policy     qw( test );

use parent "NAP::Test::Class";

=head1 NAME

Test::XTracker::Script::DB::CreateBackFillJobs

=head1 DESCRIPTION

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::DBAdminBackFillJob;

use Test::XT::DC::JQ;
use Test::File;

use XTracker::Script::DB::CreateBackFillJob;

use XTracker::Constants::FromDB     qw( :dbadmin_back_fill_job_status );
use XTracker::Config::Local         qw( config_var );


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    # get all of the Back Fill Job Statuses in so
    # that their Constant names don't need to be used
    $self->{back_fill_job_statuses} = {
        map { $_->status => $_ }
            $self->rs('DBAdmin::BackFillJobStatus')->all
    };

    $self->{jq} = Test::XT::DC::JQ->new;

    # the name of the JQ Worker
    # that processes the Jobs
    $self->{jq_worker_short_name} = 'Receive::DB::RunBackFillJob';
    $self->{jq_worker}            = 'XT::JQ::DC::' . $self->{jq_worker_short_name};

    # clear the Job Queue
    $self->jq->clear_ok;
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    # Start a transaction, so we can rollback after testing
    $self->schema->txn_begin;

    # set any existing Back-Fill jobs to 'Cancelled'
    Test::XTracker::Data::DBAdminBackFillJob->cancel_existing_back_fill_jobs;
}

sub teardown : Test( teardown => no_plan ) {
    my $self    = shift;
    $self->SUPER::teardown;

    # rollback changes done in a test
    # so they don't affect the next test
    $self->schema->txn_rollback;

    # clear the instance of $self->{script_obj}
    $self->{script_obj} = undef;

    # clear the Job Queue
    $self->jq->clear_ok;
}


=head1 TEST METHODS

=head2 test_defaults

This tests that the expected defaults are used when instantiating
the Script Class when NO options are passed to the Constructor.

=cut

sub test_defaults : Tests {
    my $self    = shift;

    my $obj = $self->script_obj;

    my %expected    = (
            verbose          => 0,
            dryrun           => 0,
            job_queue_worker => $self->{jq_worker_short_name},
        );
    my %got = map { $_ => $obj->$_ } keys %expected;

    is_deeply( \%got, \%expected, "Class has expected Defaults" );

    return;
}

=head2 test_script_populates_job_queue_with_jobs_that_are_ok_to_run

This tests that the Script only populates the Job Queue with Back
Fill Jobs that are ok to be run, ie: that their Status is correct.

=cut

sub test_script_populates_job_queue_with_jobs_that_are_ok_to_run : Tests {
    my $self    = shift;

    my $current_time = $self->schema->db_now;

    # this allows the use of the Name of the Status instead of the Constant
    my $back_fill_job_statuses = $self->{back_fill_job_statuses};

    # create a series of Back Fill Job records and then
    # call the Script and make sure only the expected
    # ones appear on the Job Queue.

    # specify the arguments to create the Jobs
    my @back_fill_job_args = (
        {
            # this should result in a Job Queue entry
            back_fill_job_status => 'New',
        },
        {
            # this should NOT result in a Job Queue entry
            back_fill_job_status => 'New',
            start_time           => $current_time->clone->add( days => 1 ),
        },
        {
            # this should result in a Job Queue entry
            back_fill_job_status => 'In Progress',
        },
        {
            # this should NOT result in a Job Queue entry
            back_fill_job_status => 'In Progress',
            start_time           => $current_time->clone->add( days => 1 ),
        },
        # these should NOT result in Job Queue entries
        {
            back_fill_job_status => 'On Hold',
        },
        {
            back_fill_job_status => 'Cancelled',
        },
    );

    # create the Back Fill Job records in the same sequence as
    # they have been specified in the Create arguments above
    my @back_fill_recs;
    foreach my $args ( @back_fill_job_args ) {
        my $rec = Test::XTracker::Data::DBAdminBackFillJob->create_one_back_fill_job( {
            back_fill_job_status_id => $back_fill_job_statuses->{ $args->{back_fill_job_status} }->id,
            ( $args->{start_time} ? ( time_to_start_back_fill => $args->{start_time} ) : () ),
        } );
        push @back_fill_recs, $rec;
    }

    # create the Expected Job Payloads
    my @expected_payloads = (
        map {
            {
                back_fill_job_id => $_->id,
                job_name         => $_->name,
            }
        } @back_fill_recs[0,2],     # only 1st & 3rd Back-Fill Jobs should appear on the queue
    );

    # now run the Script
    my $obj = $self->script_obj;
    $obj->invoke;

    foreach my $expected ( @expected_payloads ) {
        my $job_name = $expected->{back_fill_job_id} . ' - ' . $expected->{job_name};
        $self->jq->has_job_ok(
            {
                funcname => $self->{jq_worker},
                payload  => $expected,
            },
            "Job placed on Queue for Back Fill Job: '${job_name}'"
        );
    }
}

=head2 test_creating_multiple_jobs_per_back_fill_job

This tests that the Script will create Multiple JQ Jobs for a
Back Fill Job that wants multiple JQ Jobs created for it each
time.

=cut

sub test_creating_multiple_jobs_per_back_fill_job : Tests {
    my $self = shift;

    # create somef Back Fill Jobs, one where zero
    # JQ Jobs are required, one where Ten JQ Jobs
    # are required and one where One JQ Job is
    # required.
    my ( $zero_jq_jobs_wanted, $one_jq_job_wanted, $ten_jq_jobs_wanted ) =
        Test::XTracker::Data::DBAdminBackFillJob->create_back_fill_jobs( 3, [
            { max_jobs_to_create => 0  },
            { max_jobs_to_create => 1  },
            { max_jobs_to_create => 10 },
        ] );

    # now run the Script
    my $obj = $self->script_obj;
    $obj->invoke;

    # get all The Jobs for the JQ Worker we want, use the
    # 'as_hash' method so that the Job contents can be read
    my @all_jq_jobs = grep { $_->{funcname} eq $self->{jq_worker} }
                        map { $_->as_hash }
                            $self->jq->get_all_jobs;
    cmp_ok( scalar( @all_jq_jobs ), '==', 11, "Expected Number of Job Queue Jobs were Created" );

    # check that NO JQ Jobs were created
    # when ZERO Jobs were asked for
    my $got = scalar(
        grep { $_->{payload}{back_fill_job_id} == $zero_jq_jobs_wanted->id }
            @all_jq_jobs
    );
    cmp_ok( $got, '==', 0, "Didn't Find Any JQ Jobs when ZERO JQ Jobs to create is Requested" );

    # check that ONE JQ Job gets created
    $got = scalar(
        grep { $_->{payload}{back_fill_job_id} == $one_jq_job_wanted->id }
            @all_jq_jobs
    );
    cmp_ok( $got, '==', 1, "One JQ Job found when only One is Requested" );

    # check that TEN JQ Job gets created
    $got = scalar(
        grep { $_->{payload}{back_fill_job_id} == $ten_jq_jobs_wanted->id }
            @all_jq_jobs
    );
    cmp_ok( $got, '==', 10, "One JQ Job found when only One is Requested" );
}

=head2 test_processing_nothing_is_ok

Test that the Script is ok to process nothing.

=cut

sub test_processing_nothing_is_ok : Tests {
    my $self = shift;

    # in 'setup' all existing 'dbadmin.back_fill_job' records
    # will be set to 'Cancelled' so there will be nothing for
    # the Script to do.

    lives_ok {
        my $obj = $self->script_obj;
        $obj->invoke;
    } "Script runs ok when there's nothing to do";

    $self->jq->does_not_have_job_ok(
        { funcname => $self->{jq_worker} },
        "and No Back Fill Jobs were placed on the JQ",
    );
}

=head2 test_when_in_verbose_mode

Tests that with the 'verbose' switch on that the script still does what it's supposed to.

=cut

sub test_when_in_verbose_mode : Tests {
    my $self    = shift;

    my $back_fill_job_rec = Test::XTracker::Data::DBAdminBackFillJob->create_one_back_fill_job();

    $self->_new_instance( { verbose => 1 } );
    $self->script_obj->invoke();

    $self->jq->has_job_ok(
        {
            funcname => $self->{jq_worker},
            payload  => {
                back_fill_job_id => $back_fill_job_rec->id,
                job_name         => $back_fill_job_rec->name,
            },
        },
        "a Job was placed on the Queue"
    );
}

=head2 test_when_in_dryrun_mode_no_files_are_created

Tests that when the 'dryrun' switch is on that NO Jobs are placed on the JQ.

=cut

sub test_when_in_dryrun_mode_no_messages_sent : Tests {
    my $self    = shift;

    my $back_fill_job_rec = Test::XTracker::Data::DBAdminBackFillJob->create_one_back_fill_job();

    # when called from the wrapper script 'verbose' will be TRUE too
    $self->_new_instance( { dryrun => 1, verbose => 1 } );

    # run the script
    $self->script_obj->invoke();

    $self->jq->does_not_have_job_ok(
        { funcname => $self->{jq_worker} },
        "No Back Fill Job was placed on the JQ",
    );
}

=head2 test_wrapper_script

Tests the wrapper perl script that inbokes the Script class exists and is executable.
Then tests that it can be executed in 'dryrun' mode and NO Jobs are placed on the JQ.

Wrapper Script:
    script/housekeeping/db/create_back_fill_jobs.pl

=cut

sub test_script_wrapper : Tests {
    my $self    = shift;

    my $script  = config_var('SystemPaths','xtdc_base_dir')
                  . '/script/housekeeping/db/create_back_fill_jobs.pl';

    note "Testing Wrapper Script: ${script}";

    file_exists_ok( $script, "Wrapper Script exists" );
    file_executable_ok( $script, "and is executable" );

    note "attempt to run script in 'dryrun' mode";

    # rollback deletion of any real data (done in 'setup')
    $self->schema->txn_rollback;

    $self->schema->txn_begin;
    my $rec = Test::XTracker::Data::DBAdminBackFillJob->create_one_back_fill_job();
    $self->schema->txn_commit;  # need to commit the data otherwise the
                                # Script wouldn't pick up the data anyway

    system( $script, '-d' );    # run script in Dry-Run mode
    my $retval  = $?;
    if ( $retval == -1 ) {
        fail( "Script failed to Execute: ${retval}" )
    }
    else {
        cmp_ok( ( $retval & 127 ), '==', 0, "Script Executed OK: ${retval}" );
    }

    # check NO Jobs placed on the JQ
    $self->jq->does_not_have_job_ok(
        { funcname => $self->{jq_worker} },
        "No Back Fill Jobs were placed on the JQ",
    );

    # remove test data
    $rec->delete;

    # 'teardown' will fail if not in a transaction
    $self->schema->txn_begin;
}

#-----------------------------------------------------------------------------------------

# get a new instance of the Script object, can
# pass options for the constructor if needed
sub _new_instance {
    my ( $self, $options )  = @_;
    $self->{script_obj} = undef;        # need this otherwise the 'SingleInstance' feature
                                        # will block new instantiations of the Class

    $self->{script_obj} = XTracker::Script::DB::CreateBackFillJob->new( $options || {} );

    # need to use our copy of Schema & DBH
    $self->{script_obj}->{schema}   = $self->schema;
    $self->{script_obj}->{dbh}      = $self->schema->storage->dbh;

    return;
}

# returns the instance of the Script object
# that '_new_instance' has instantiated
sub script_obj {
    my $self = shift;
    $self->_new_instance            if ( !$self->{script_obj} );
    return $self->{script_obj};
}

sub jq {
    my $self = shift;
    return $self->{jq};
}


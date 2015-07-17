#!/usr/bin/env perl

use NAP::policy     qw( test );

use parent 'NAP::Test::Class';

=head1 NAME

db_run_back_fill_job.t

=head1 DESCRIPTION

Tests the 'Receive::DB::RunBackFillJob' worker

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::DBAdminBackFillJob;

use Test::MockObject;

use XTracker::Constants::FromDB         qw( :dbadmin_back_fill_job_status );

use Mock::Quick;


sub startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->{jobq_worker} = 'Receive::DB::RunBackFillJob';

    use_ok( 'XT::JQ::DC::' . $self->{jobq_worker} );
}

sub setup: Test( setup => no_plan ) {
    my $self = shift;
    $self->schema->txn_begin;
}

sub teardown : Tests( teardown => no_plan ) {
    my $self = shift;
    $self->schema->txn_rollback();
}

=head1 TESTS

=head2 test_running_back_fill_job

Test running a Back Fill Job and also check that only
Jobs at the Correct Status are actually run.

=cut

sub test_running_back_fill_job : Tests {
    my $self = shift;

    my $new_customer = Test::XTracker::Data->create_dbic_customer( {
        channel_id   => Test::XTracker::Data->channel_for_nap->id,
    } );
    # make sure the Customer's 'credit_check'
    # field is already updated to some value
    $new_customer->discard_changes->update( {
        credit_check => \'now()',
    } );

    # arguments to create a Valid UPDATE Statement for a Back Fill Job
    my %job_create_args = (
        resultset_select            => undef,
        resultset_order_by          => undef,
        max_rows_to_update          => 2,
        back_fill_table_name        => 'customer',
        back_fill_primary_key_field => 'id',
        update_set                  => 'credit_check = now()',
        resultset_from              => 'customer',
        # only update the Customer the test has created, don't want
        # to get all Customers that have been created by other tests
        resultset_where             => "credit_check IS NULL AND id = " . $new_customer->id,
    );

    my %tests = (
        "Back Fill Job is at a Valid Status" => {
            setup => {
                back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
            },
            expect => {
                run_log_record => 1,
                email_subject  => qr/Complete/i,
                email_body     => qr/Status.*Completed/i,
            },
        },
        "Back Fill Job already Completed - doesn't Run anything" => {
            setup => {
                back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED,
            },
            expect => {
                run_log_record => 0,
                email_subject  => qr/^$/,
                email_body     => qr/^$/,
            },
        },
        "Back Fill Job that will generate an Invalid SQL UPDATE" => {
            setup => {
                back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
                # placholders will throw and error
                update_set              => 'credit_check = ?',
            },
            expect => {
                run_log_record => 1,
                with_error     => 1,
                email_subject  => qr/Error/i,
                email_body     => qr/Can't create a Statement Handle/si,
            },
        },
    );

    my $email_subject;
    my $email_body;
    my $mock_email = qtakeover 'XTracker::EmailFunctions' => (
        send_email => sub {
            my @params = @_;
            $email_subject = $params[3];
            $email_body    = $params[4];
            return 1;
        },
    );

    foreach my $label ( keys %tests ) {
        note "TEST: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        $email_subject = '';
        $email_body    = '';

        my $back_fill_job_rec = Test::XTracker::Data::DBAdminBackFillJob->create_one_back_fill_job( {
            %job_create_args,
            %{ $setup },
        } );
        $back_fill_job_rec->log_back_fill_job_runs->delete;

        # build the Payload for the Worker
        my $payload = {
            back_fill_job_id => $back_fill_job_rec->id,
            job_name         => $back_fill_job_rec->name,
        };

        # put the Job on the Queue and run it
        lives_ok {
            $self->_send_job( $payload, $self->{jobq_worker} );
        } "Send Run Back Fill Job to the Queue and Run it";

        $back_fill_job_rec->discard_changes;
        my $got_log_rec = $back_fill_job_rec->log_back_fill_job_runs->first;
        if ( $expect->{run_log_record} ) {
            isa_ok( $got_log_rec, 'XTracker::Schema::Result::DBAdmin::LogBackFillJobRun' );
            cmp_ok( $got_log_rec->error_was_thrown, '==', $expect->{with_error} // 0,
                            "and the 'error_was_thrown' flag is set as Expected" );
        }
        else {
            ok( !defined $got_log_rec, "NO 'log_back_fill_job_run' record was Created" )
                            or diag "ERROR - record was Created: " . p( $got_log_rec );
        }

        like( $email_subject, $expect->{email_subject}, "Email Subject as Expected" );
        like( $email_body, $expect->{email_body}, "Email Body as Expected" );
    }


    # un-mock
    $mock_email->restore('send_email');
    $mock_email = undef;
}

#--------------------------------------------------------------

# Creates and executes a job
sub _send_job {
    my $self = shift;
    my $payload = shift;
    my $worker  = shift;

    note "Job Payload: " . p( $payload );

    my $fake_job    = _setup_fake_job();
    my $funcname    = 'XT::JQ::DC::' . $worker;
    my $job         = new_ok( $funcname => [
        payload => $payload,
        schema  => $self->{schema},
        dbh     => $self->{schema}->storage->dbh,
    ] );
    my $errstr      = $job->check_job_payload($fake_job);
    die $errstr     if ( $errstr );
    $job->do_the_task( $fake_job );

    return $job;
}

# setup a fake TheShwartz::Job
sub _setup_fake_job {
    my $fake = Test::MockObject->new();
    $fake->set_isa('TheSchwartz::Job');
    $fake->set_always( completed => 1 );
    return $fake;
}

Test::Class->runtests;

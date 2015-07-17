=head1 NAME

Test::XT::DC::JQ - Test jobs in the job queue

=head1 SYNOPSIS

  use Test::XT::DC::JQ;

  my $jqt = Test::XT::DC::JQ->new;
  $jqt->clear_ok;      # clear job queue
  $jqt->has_jobs_ok;   # ok if *any* jobs exist
  $jqt->is_empty_ok;   # ok if *no* jobs exist

  # these only compare keys that are in the %wanted hash,
  # extra fields found in the job are ignored:
  $jqt->has_job_ok
    ({
      funcname => 'XT::Job::DC::Test0',
      payload  => { testing => 'this' },
      feedback_to => { 'yer mom' },
     }, 'has test job' );

  # is_first_job and is_last_job will give you better diags if the fail than
  # has_job_ok
  # Note that there is an edge case where the diff will wrongly hilight
  # '1' vs 1 when something else is wrong
  $jqt->is_first_job
    ({
      funcname => 'XT::Job::DC::Test1',
      payload  => { testing => 'this' },
      remote_targets => [ 'DC1' ],
     }, 'first job is test1' );

  $jqt->is_last_job
    ({
      funcname => 'XT::Job::DC::Test2',
      payload  => { testing => 'that' },
     }, 'last job is test2' );

  # Try processing a job:
  my $job_handle = XT::JQ::DC->new({ funcname => 'Summat' })->send_job;
  $jqt->process_job_ok( $job_handle );

  # this uses TheSchwartz::JobHandle objects:
  my $job_handle = $jqt->get_last_job_handle;
  $jqt->remove_job_ok( $job_handle );

=cut

package Test::XT::DC::JQ;

# Ensure we have the required version
use XT::Common 1.00014;

use Moose;

extends 'Test::XT::JQ';

no Moose;

sub _build_schema {
    require Test::XTracker::Model;
    return Test::XTracker::Model::get_jq_schema();
}

sub _build_queue {
    require XT::JQ::DC::Queue;
    return XT::JQ::DC::Queue->new({worker_group => 'LEGACY'});
}

=head1 METHODS

=head2 does_not_have_job_ok

    $ok = $jqt->does_not_have_job_ok( {
                funcname => 'XT::Job::DC::Test1',
            } );
        or
    $ok = $jqt->does_not_have_job_ok( {
                funcname => 'XT::Job::DC::Test1',
            }, "Test Message" );

Tests that a Job s NOT on the Queue.

=cut

sub does_not_have_job_ok {
    my ( $self, $args, $message ) = @_;

    $message ||= 'Job Not Found on Queue';

    my $rs = $self->get_jobs_rs->search(
        {
            'func.funcname' => $args->{funcname},
        },
        {
            join => 'func',
        }
    );

    my $num_jobs = $rs->count;
    my $ok = ( $num_jobs == 0 );
    $self->builder->ok( $ok, $message )
                        or print STDERR "ERROR - ${message}: Number of Jobs found: ${num_jobs}\n";

    return $ok;
}

1;

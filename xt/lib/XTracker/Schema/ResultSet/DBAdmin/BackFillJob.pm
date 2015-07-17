package XTracker::Schema::ResultSet::DBAdmin::BackFillJob;

use strict;
use warnings;

use base 'XTracker::Schema::ResultSetBase';

=head1 NAME

XTracker::Schema::ResultSet::DBAdmin::BackFillJob - DBIC resultset

=head1 DESCRIPTION

DBIx::Class resultset for Back Fill Jobs

=cut

use Carp;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :dbadmin_back_fill_job_status );

use Moose;
with
    'XTracker::Schema::Role::ResultSet::WithStatus' => {
        column   => 'back_fill_job_status_id',
        statuses => {
           cancelled   => $DBADMIN_BACK_FILL_JOB_STATUS__CANCELLED,
           completed   => $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED,
           in_progress => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
           is_new      => $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
           on_hold     => $DBADMIN_BACK_FILL_JOB_STATUS__ON_HOLD,
        },
    },
    'XTracker::Schema::Role::ResultSet::Orderable' => {
        order_by => {
            id => 'id',
        },
    },
;


=head1 METHODS

=head2 get_runnable_jobs

    $resultset = $self->get_runnable_jobs;

Returns a Result Set for all the Back Fill Job records which can
be run, which are those that are set to 'New' or 'In Progress' and
whose 'time_to_start_back_fill' Time is <= current time.

=cut

sub get_runnable_jobs {
    my $self = shift;

    return $self->search( {
        back_fill_job_status_id => {
            -in => [
                $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
                $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
            ],
        },
        time_to_start_back_fill => { '<=' => \'now()' },
    } );
}

1;

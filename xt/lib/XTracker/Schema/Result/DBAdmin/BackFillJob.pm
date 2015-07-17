use utf8;
package XTracker::Schema::Result::DBAdmin::BackFillJob;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("dbadmin.back_fill_job");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dbadmin.back_fill_job_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 150 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "back_fill_job_status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "back_fill_table_name",
  { data_type => "text", is_nullable => 0 },
  "back_fill_primary_key_field",
  { data_type => "text", is_nullable => 0 },
  "update_set",
  { data_type => "text", is_nullable => 0 },
  "resultset_select",
  { data_type => "text", is_nullable => 1 },
  "resultset_from",
  { data_type => "text", is_nullable => 0 },
  "resultset_where",
  { data_type => "text", is_nullable => 0 },
  "resultset_order_by",
  { data_type => "text", is_nullable => 1 },
  "max_rows_to_update",
  { data_type => "integer", is_nullable => 0 },
  "max_jobs_to_create",
  { data_type => "integer", is_nullable => 0 },
  "time_to_start_back_fill",
  { data_type => "timestamp with time zone", is_nullable => 0 },
  "contact_email_address",
  { data_type => "text", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "back_fill_job_status",
  "XTracker::Schema::Result::DBAdmin::BackFillJobStatus",
  { id => "back_fill_job_status_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "log_back_fill_job_runs",
  "XTracker::Schema::Result::DBAdmin::LogBackFillJobRun",
  { "foreign.back_fill_job_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_back_fill_job_statuses",
  "XTracker::Schema::Result::DBAdmin::LogBackFillJobStatus",
  { "foreign.back_fill_job_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:t3gMisE0A6g5cKlByDyXtg

use DateTime;
use Carp;
use Try::Tiny;

use XTracker::Constants::FromDB     qw( :dbadmin_back_fill_job_status );

use Moose;
with
    'XTracker::Schema::Role::WithStatus' => {
        column   => 'back_fill_job_status_id',
        statuses => {
            cancelled   => $DBADMIN_BACK_FILL_JOB_STATUS__CANCELLED,
            completed   => $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED,
            in_progress => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
            new         => $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
            on_hold     => $DBADMIN_BACK_FILL_JOB_STATUS__ON_HOLD,
        }
    }
;

use XTracker::Logfile           qw( xt_logger );

use XTracker::EmailFunctions    qw( send_internal_email );


=head1 METHODS

=head2 job_ok_to_run

    $boolean = $self->job_ok_to_run;

If it is ok to run the Job then this method will
return TRUE, but if the Status of the Job is neither
'New' or 'In Progress' or the Time to start the Job
hasn't passed yet then it will return FALSE.

=cut

sub job_ok_to_run {
    my $self = shift;

    return 0    unless ( $self->is_new || $self->is_in_progress );
    return $self->has_start_time_passed;
}

=head2 has_start_time_passed

    $boolean = $self->has_start_time_passed;

This will return TRUE or FALSE based on whether the time
in the 'time_to_start_back_fill' field has passed compared
to now.

=cut

sub has_start_time_passed {
    my $self    = shift;

    # get 'now()' from the DB
    my $db_now = $self->result_source->schema->db_now();

    # compare it to the value in 'time_to_start_back_fill'
    my $result = $db_now->compare( $self->time_to_start_back_fill );

    # if 0 or 1 is returned then 'now()' >= 'time_to_start_back_fill'
    return ( $result >= 0 ? 1 : 0 );
}

=head2 update_status

    $log_record = $self->update_status( $status_id, $operator_id );

Updates the Status to the Status Id provided and creates a 'log_back_fill_job_status'
record using the Operator Id passed in.

=cut

sub update_status {
    my ( $self, $status_id, $operator_id ) = @_;

    croak "No Status Id was passed in to '" . __PACKAGE__ . "->update_status'"
                    if ( !$status_id );
    croak "No Operator Id was passed in to '" . __PACKAGE__ . "->update_status'"
                    if ( !$operator_id );

    $self->update( {
        back_fill_job_status_id => $status_id,
    } );

    return $self->create_related( 'log_back_fill_job_statuses', {
        back_fill_job_status_id => $status_id,
        operator_id             => $operator_id,
    } );
}

=head2 mark_as_completed

    $self->mark_as_completed( $operator_id );

Sets the Status of the Back Fill Job record to be 'Completed', requires
the Operator Id as a Status Log record is also created.

=cut

sub mark_as_completed {
    my ( $self, $operator_id ) = @_;

    croak "No Operator Id was passed in to 'mark_as_completed'"
                    if ( !$operator_id );

    $self->update_status( $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED, $operator_id );

    return;
}

=head2 mark_as_in_progress

    $self->mark_as_in_progress( $operator_id );

Sets the Status of the Back Fill Job record to be 'In Progress', requires
the Operator Id as a Status Log record is also created.

=cut

sub mark_as_in_progress {
    my ( $self, $operator_id ) = @_;

    croak "No Operator Id was passed in to 'mark_as_in_progress'"
                    if ( !$operator_id );

    $self->update_status( $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS, $operator_id );

    return;
}

=head2 log_outcome_and_set_status_after_running_job

    $self->log_outcome_and_set_status_after_running_job(
        $db_back_fill_obj,
        $operator_id
    );

This method should be called after running a Back Fill Job using an
instance of the Class 'XT::DB::BackFill'. It will create a new
'log_back_fill_job_run' using the Attributes/Methods on the passed
in 'XT::DB::BackFill' object. The Operator Id passed in will be
used on the Log records.

If the number of records update by the Back Fill Job is ZERO (and
no errors were thrown) then the Status of the Back Fill Job record
will be set to 'Completed', otherwise the Status of the record will
be set as 'In Progress' if its current Status is 'New'.

=cut

sub log_outcome_and_set_status_after_running_job {
    my ( $self, $backfill_obj, $operator_id ) = @_;

    croak "No Back Fill Job Object was passed to 'log_outcome_and_set_status_after_running_job'"
                    if ( !$backfill_obj );
    croak "No Operator Id was passed to 'log_outcome_and_set_status_after_running_job'"
                    if ( !$operator_id );

    # check if the Job has actually been run
    if ( !$backfill_obj->was_run ) {
        croak "The Back Fill Job: '" . $self->name . "' wasn't run, so can't create Logs, " .
              "in 'log_outcome_and_set_status_after_running_job'";
    }

    # create a Run Log record
    $self->create_related( 'log_back_fill_job_runs', {
        number_of_rows_updated => $backfill_obj->record_count,
        error_was_thrown       => $backfill_obj->run_and_error_thrown,
        start_time             => $backfill_obj->start_time,
        finish_time            => $backfill_obj->finish_time,
        operator_id            => $operator_id,
    } );

    # set the Status of the Back Fill Job record
    if ( $self->is_new && $backfill_obj->run_and_error_thrown ) {
        # if an Error was Thrown and the Status was New
        $self->mark_as_in_progress( $operator_id );
    }
    elsif ( $self->is_new && $backfill_obj->record_count ) {
        # if No Error was Thrown and some records were Updated
        $self->mark_as_in_progress( $operator_id );
    }
    elsif ( $backfill_obj->run_and_successful && $backfill_obj->record_count == 0 ) {
        # if the run was a Success (No Error was Thrown) and ZERO records were Updated
        $self->mark_as_completed( $operator_id );
    }
    else {
        # leave the Status unchanged
    }

    return;
}

=head2 send_email_to_contact_address

    $email_sent = $self->send_email_to_contact_address( $subject_suffix, {
        # optional
        extra_information => '...',     # this will be left untouched and appear in the email body
    } );

Sends an Internal Email to the Email Address in the 'contact_email_address'
field.

Pass in the Subject Suffix that will go after the following in the Subject:

    [DB Back-Fill Alert] Back-Fill Job Id: 12345, $subject_suffix

It uses the following template:

    email/internal/db_back_fill_job_alert.tt

=cut

sub send_email_to_contact_address {
    my ( $self, $subject_suffix, $args ) = @_;

    my $subject = '[DB Back-Fill Alert] Back-Fill Job Id: ' . $self->id;
    $subject   .= ", ${subject_suffix}"     if ( $subject_suffix );

    my $sent_email_result;
    try {
        $sent_email_result = send_internal_email(
            to      => $self->contact_email_address,
            subject => $subject,
            from_file => {
                path => 'email/internal/db_back_fill_job_alert.tt',
            },
            stash => {
                %{ $args // {} },
                back_fill_job_rec => $self,
                template_type     => 'email',
            },
        );
    } catch {
        my $err = $_;
        # log the error but it's not worth dieing for
        xt_logger->warn( "Couldn't Send an Email for Back-Fill Job Id: " . $self->id . ", Error: " . $err );
    };

    return $sent_email_result;
}


1;

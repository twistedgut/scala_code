package XT::JQ::DC::Receive::DB::RunBackFillJob;

use Moose;
extends 'XT::JQ::Worker';

use MooseX::Types::Moose        qw( Int Str );
use MooseX::Types::Structured   qw( Dict Optional );

use XTracker::Logfile           qw( xt_logger );
use XTracker::Constants         qw( :application );

use XT::DB::BackFill;

use Try::Tiny;

use Benchmark       qw( :hireswallclock );


has payload => (
    is => 'ro',
    isa => Dict[
        back_fill_job_id => Int,
        job_name         => Optional[Str],
    ],
    required => 1,
);

has logger => (
    is => 'ro',
    default => sub { return xt_logger('XT::JQ::DC'); }
);


sub do_the_task {
    my ($self, $job) = @_;
    my $error    = "";

    my $schema = $self->schema;

    my $job_id = $self->payload->{back_fill_job_id};

    my $back_fill_job_rec = $self->schema->resultset('DBAdmin::BackFillJob')->find( $job_id );

    # create a string to represent the Job in Log messages
    my $job_name_for_log = "(${job_id}) " . $back_fill_job_rec->name;

    # don't bother doing anything if the Job can't be run
    if ( !$back_fill_job_rec->job_ok_to_run ) {
        $self->logger->info(
            "Back Fill Job - '${job_name_for_log}', CAN'T be run. " .
            "Status: '" . $back_fill_job_rec->back_fill_job_status->status . "', " .
            "Start Time: '" . $back_fill_job_rec->time_to_start_back_fill . "'"
        );
        return;
    }

    $self->logger->info( "Processing Back Fill Job - '${job_name_for_log}'" );

    my $benchmark_log = xt_logger('Benchmark');

    my $no_error = 1;
    my $number_of_records = 0;
    my $back_fill_obj;

    my $benchmark_start = Benchmark->new;

    try {
        $back_fill_obj = XT::DB::BackFill->new( {
            back_fill_job => $back_fill_job_rec,
        } );
        $number_of_records = $back_fill_obj->run_job;
    }
    catch {
        $error    = $_;
        $no_error = 0;

        $self->logger->error( qq{Failed job for Back Fill Job - '$job_name_for_log', error: $error} );

        $job->failed( $error );

        $back_fill_job_rec->send_email_to_contact_address( 'had an Error', {
            extra_information => $error,
        } );
    };

    # log the outcome if the Back Fill object was run
    if ( $back_fill_obj && $back_fill_obj->was_run ) {
        $back_fill_job_rec->log_outcome_and_set_status_after_running_job(
            $back_fill_obj,
            $APPLICATION_OPERATOR_ID,
        );

        if ( $back_fill_job_rec->is_completed ) {
            $back_fill_job_rec->send_email_to_contact_address('has now Completed');
        }
    }

    if ( $no_error ) {
        my $benchmark_stop = Benchmark->new;
        $benchmark_log->info(
            "JQ, Run Back Fill Job - '${job_name_for_log}', " .
            "Number of Records Updated: '${number_of_records}', " .
            "Total Time = '" . timestr( timediff( $benchmark_stop, $benchmark_start ), 'all' ) . "'"
        );
        $self->logger->info(
            "Finished Processing Back Fill Job - '${job_name_for_log}', " .
            "Number of Records Updated: '${number_of_records}'"
        );
    }

    return;
}

sub check_job_payload {
    my ($self, $job) = @_;
    return ();
}


1;

__END__

=head1 NAME

XT::JQ::DC::Receive::DB::RunBackFillJob

=head1 DESCRIPTION

Expected Payload should look like:

    my $job_payload    = {
        back_fill_job_id => 23124,      # the Id of the 'dbadmin.back_fill_job'
                                        # record that will be run
        # this is optional and used for information purposes
        # when looking at the Payloads of Jobs in the Queue
        job_name         => 'a name for the job',
    };

This Worker is used to Back-fill new Columns on existing Tables. It is passed the Id of
the 'dbadmin.back_fill_job' record and will run the Job to back-fill the records by
creating an instance of 'XT::DB::BackFill' and calling the method 'run_job' against it.

=cut

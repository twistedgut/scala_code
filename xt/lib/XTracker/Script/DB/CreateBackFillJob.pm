package XTracker::Script::DB::CreateBackFillJob;

use NAP::policy     qw( class );
extends 'XT::Common::Script';

with map { "XTracker::Script::Feature::$_" } qw(
    SingleInstance
    Schema
    Logger
);

sub log4perl_category { return 'Script_CreateBackFillJob' }

use XT::JQ::DC;


=head1 NAME

XTracker::Script::DB::CreateBackFillJob

=head1 SYNOPSIS

    # in a small perl script:

    XTracker::Script::DB::CreateBackFillJob->new( { ... } )->invoke();

=head1 DESCRIPTION

This Script creates 'DB::RunBackFillJob' Jobs on the TheSchwartz Job Queue.

It will use the 'dbadmin.back_fill_job' table to determine which records
to create JQ Jobs for and will only do so for Records that are at the
correct Status and whose Start Time has passed.

The JQ Worker that will process these Jobs is:

    XT::JQ::DC::Receive::DB::RunBackFillJob

=cut


=head1 ATTRIBUTES

=head2 verbose

A Boolean switch passed in from the command line that if TRUE
will output extra informationt to the screen and log, will be
set to TRUE if 'dryrun' is used.

=head2 dryrun

A Boolean switch passed in from the command line that if TRUE
will mean NO Jobs are placed on the JQ.

=head2 back_fill_job_rs

The Result-Set used by the Script.

=head2 job_queue_worker

The JQ Worker that will process the Jobs:

    XT::JQ::DC::Receive::DB::RunBackFillJob

=cut

has verbose => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has dryrun => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has back_fill_job_rs => (
    is      => 'rw',
    isa     => 'XTracker::Schema::ResultSet::DBAdmin::BackFillJob',
    lazy    => 1,
    builder => '_build_back_fill_job_rs',
    init_arg=> undef,
);

has job_queue_worker => (
    is      => 'ro',
    isa     => 'Str',
    init_arg=> undef,
    default => 'Receive::DB::RunBackFillJob',
);


sub _build_back_fill_job_rs {
    my $self = shift;
    return $self->schema->resultset('DBAdmin::BackFillJob')
                            ->get_runnable_jobs
                                ->order_by_id;
}


=head1 METHODS

=over 4

=item B<invoke>

Script entry point

=back

=cut

sub invoke {
    my ( $self )        = @_;

    $self->log_info("Script Started");

    my $rs  = $self->back_fill_job_rs;

    my @payload;

    # count the number of Back-Fill Jobs processed
    my $counter = 0;

    # there is an Option on the Back-Fill Job
    # record to place multiple Jobs on the JQ
    # when this script runs, this counter will
    # count the Total Jobs placed on the JQ
    my $jq_jobs_per_back_fill_job = 0;

    REC:
    while ( my $rec = $rs->next ) {
        if ( $counter == 0 ) {
            # for useful infomation log when
            # the first record gets processed
            $self->log_info("Processing FIRST Record");
        }

        # make it easier to put the record's Id in log messages
        my $back_fill_job_log_msg = "Back-Fill Job Id: " . $rec->id;

        # number of JQ Jobs to Create
        my $jq_jobs_to_create = $rec->max_jobs_to_create;

        $counter++;

        if ( $jq_jobs_to_create == 0 ) {
            $self->log_info( "${back_fill_job_log_msg}, wants ZERO Jobs placed on the JQ" );
            next REC;
        }

        $self->log_info( "${back_fill_job_log_msg}, will place ${jq_jobs_to_create} Jobs on the JQ" );

        foreach ( 1..$jq_jobs_to_create ) {
            my $jq_jobid = $self->_create_jq_job( $rec );

            $self->log_info( "Created JQ Job with JobId: ${jq_jobid}, for ${back_fill_job_log_msg}" );

            $jq_jobs_per_back_fill_job++;
        }
    }

    $self->log_info(
        "Back Fill Job records Processed: ${counter}, " .
        "placing ${jq_jobs_per_back_fill_job} Jobs on the JQ"
    );

    return;
}

# creates a Job Queue Job for a Back Fill Job record
sub _create_jq_job {
    my ( $self, $back_fill_job_rec ) = @_;

    my $jq_job_id;

    if ( !$self->dryrun ) {
        my $job_rq = XT::JQ::DC->new( { funcname => $self->job_queue_worker } );
        $job_rq->set_payload( {
            back_fill_job_id => $back_fill_job_rec->id,
            job_name         => $back_fill_job_rec->name,
        } );
        my $jq_job = $job_rq->send_job();
        $jq_job_id = $jq_job->jobid;
    }
    else {
        $jq_job_id = 'N/A (dry-run)';
    }

    return $jq_job_id;
}

1;

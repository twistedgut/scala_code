package Test::XTracker::Data::DBAdminBackFillJob;

use NAP::policy     qw( test );

use Test::XTracker::Data;
use Test::XT::Data;

use XTracker::Constants::FromDB     qw( :dbadmin_back_fill_job_status );


=head1 NAME

Test::XTracker::Data::DBAdminBackFillJob - To do Pre-Order Related Stuff

=head1 SYNOPSIS

    package Test::Foo;

    use Test::XTracker::Data::DBAdminBackFillJob;

    my $array_ref = Test::XTracker::Data::DBAdminBackFillJob->create_back_fill_jobs( 3 );

=cut


=head1 METHODS

=head2 create_back_fill_jobs

    # create two Back Fill Jobs just using the defaults
    @array = __PACKAGE__->create_back_fill_jobs( 2 );

    # to create three Back Fill Jobs each with a specific Status
    @array = __PACKAGE__->create_back_fill_jobs( 3, [
        # optional array ref of arguments to use for each record
        {
            back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
        },
        {
            back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__IN_PROGRESS,
        },
        {
            back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__COMPLETED,
        },
    ] );

This will use the 'Test::XT::Data::DBAdminBackFillJob' Role to create Back Fill Job
records, look in there for the Defaults that will be used.

It will create X number of Back Fill Jobs by specify the number of Jobs you want to create
by using the first parameter. If you want to specify different settings for the different
records then pass them in an Array Ref. of Hash Refs. using any options that are available
in the 'Test::XT::Data::DBAdminBackFillJob' Role, if you specify more jobs to create than
specified in the Array Ref. then the defaults will be used for the rest of the jobs.

=cut

sub create_back_fill_jobs {
    my ( $self, $number_to_create, $opts ) = @_;

    $opts //= [];

    my @records;

    foreach my $number ( 1..$number_to_create ) {
        my $framework = Test::XT::Data->new_with_traits(
            traits => [
                'Test::XT::Data::DBAdminBackFillJob',
            ],
        );

        # get any arguments that should be used for creating the record
        my $args = shift( @{ $opts } ) // {};

        ARGS:
        foreach my $accessor ( keys %{ $args } ) {
            next ARGS       if ( !$framework->can( $accessor ) );
            $framework->$accessor( $args->{ $accessor } );
        }

        my $rec = $framework->back_fill_job;
        push @records, $rec->discard_changes;
    }

    return @records;
}

=head2 create_one_back_fill_job

    $record = __PACKAGE__->create_back_fill_jobs( {
        # optional args that are the same as
        # passed to 'create_back_fill_jobs'
        back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__NEW,
    } );

Creates one Back Fill Job record by calling 'create_back_fill_jobs'
with the correct parameters to get one record, see that method for
more details.

=cut

sub create_one_back_fill_job {
    my ( $self, $args ) = @_;

    my ( $record ) = $self->create_back_fill_jobs( 1, [ $args ] );
    return $record;
}

=head2 cancel_existing_back_fill_jobs

    __PACKAGE__->cancel_existing_back_fill_jobs();

This Cancels any Back-Fill Jobs, use this if you want to Cancel
existing Back-Fill Jobs before a Test so that they don't interfere.

=cut

sub cancel_existing_back_fill_jobs {
    my $self = shift;

    my $schema = Test::XTracker::Data->get_schema();

    $schema->resultset('DBAdmin::BackFillJob')->update( {
        back_fill_job_status_id => $DBADMIN_BACK_FILL_JOB_STATUS__CANCELLED,
    } );

    return;
}

1;

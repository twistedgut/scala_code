package XT::DB::BackFill::Exception::NotAbleToRunJob;

use NAP::policy     qw( class );
extends 'XT::DB::BackFill::Exception';

=head1 NAME

XT::DB::BackFill::Exception::NotAbleToRunJob

=head1 SYNOPSIS

    package My::Class;

    ...

    use XT::DB::BackFill::Exception::NotAbleToRunJob;

    ...

    sub my_method {
        if ( !$back_fill_job_rec->has_start_time_passed ) {
            XT::DB::BackFill::Exception::NotAbleToRunJob->throw( {
                job_name   => $back_fill_job_rec->name,
                start_time => $back_fill_job_rec->time_to_start_back_fill,
                job_status => $back_fill_job_rec->back_fill_job_status->status,
            } );
        }
    };

=head1 DESCRIPTION

Used to generate an Exception when a Statement Handle for the UPDATE
SQL Statement can not be Executed.

This Class extends 'XT::DB::BackFill::Exception'.

=cut


=head1 ATTRIBUTES

=head2 +error

This is set to NOT being required for this Exception.

=cut

has '+error' => (
    required => 0,
);

=head2 start_time

The Back Fill Job's Start Time.

=cut

has start_time => (
    is => 'ro',
);

=head2 job_status

The Back Fill Job Status.

=cut

has job_status => (
    is => 'ro',
);

=head2 +message

The error message that gets generated.

=cut

has '+message' => (
    default  => '[DB Back-Fill Error] - Back Fill Job: %{job_name}s' .
                ' - Back Fill Job is NOT Able to be Run - Start Time: %{start_time}s, ' .
                ' Job Status: %{job_status}s, ' .
                ' found at %{stack_trace}s',
);


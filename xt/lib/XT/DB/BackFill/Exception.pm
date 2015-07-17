package XT::DB::BackFill::Exception;

use NAP::policy     qw( exception );

=head1 NAME

XT::DB::BackFill::Exception

=head1 SYNOPSIS

    package XT::DB::BackFill::Exception::MyError;

    extends 'XT::DB::BackFill::Exception';

    1;


    # then when an Exception occurs;
    XT::DB::BackFill::Exception::MyError->throw( {
        job_name => 'A Back Fill Job',
        error    => 'Something went wrong',
    } );


=head1 DESCRIPTION

Base Class for all 'XT::DB::BackFill' Exceptions.

=cut

=head1 ATTRIBUTES

=head2 job_name

The name of the Back-Fill Job record, this is then used in error messages.

=cut

has job_name => (
    is      => 'ro',
    isa     => 'Str',
    required=> 1,
);

=head2 error

The error that happened to cause the Exception. By default this is required but
you can extend this in your Sub-classes and make it NOT required if you don't
want a general Error passed in.

=cut

has error => (
    is      => 'ro',
    required=> 1,
);

=head2 +message

A General Error message that displays the value of 'job_name' & 'error' along
with a Stack Trace.

=cut

has '+message' => (
    default => '[DB Back-Fill Error] - Back Fill Job: %{job_name}s - with Error: %{error}, found at %{stack_trace}s',
);


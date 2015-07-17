package XT::DB::BackFill::Exception::InvalidMaxRowsToUpdate;

use NAP::policy     qw( class );
extends 'XT::DB::BackFill::Exception';

=head1 NAME

XT::DB::BackFill::Exception::InvalidMaxRowsToUpdate

=head1 SYNOPSIS

    package My::Class;

    ...

    use XT::DB::BackFill::Exception::InvalidMaxRowsToUpdate;

    ...

    sub my_method {
        if ( $max_records <= 0 ) {
            XT::DB::BackFill::Exception::InvalidMaxRowsToUpdate->throw( {
                job_name           => $back_fill_job_rec->name,
                max_rows_to_update => $back_fill_job_rec->max_rows_to_update,
            } );
        }
    };

=head1 DESCRIPTION

Used to generate an Exception when the value of the 'max_rows_to_update'
field doesn't have a valid value.

This Class extends 'XT::DB::BackFill::Exception'.

=cut


=head1 ATTRIBUTES

=head2 +error

This is set to NOT being required for this Exception.

=cut

has '+error' => (
    required => 0,
);

=head2 max_rows_to_update

The value of the 'max_rows_to_update' that is invalid.

=cut

has max_rows_to_update => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
);

=head2 +message

The error message that gets generated.

=cut

has '+message' => (
    default  => '[DB Back-Fill Error] - Back Fill Job: %{job_name}s' .
                " - Invalid 'max_rows_to_update' Value: \%{max_rows_to_update}s," .
                ' found at %{stack_trace}s',
);


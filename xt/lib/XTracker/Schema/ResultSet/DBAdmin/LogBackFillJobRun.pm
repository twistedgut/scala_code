package XTracker::Schema::ResultSet::DBAdmin::LogBackFillJobRun;

use strict;
use warnings;

use base 'XTracker::Schema::ResultSetBase';

=head1 NAME

XTracker::Schema::ResultSet::DBAdmin::LogBackFillJobRun - DBIC resultset

=head1 DESCRIPTION

DBIx::Class resultset for Log Back Fill Job Run records.

=cut

use Carp;

use Moose;
with
    'XTracker::Schema::Role::ResultSet::Summable' => {
        sums => {
            total_rows_updated => [ 'number_of_rows_updated' ],
        },
    },
;


=head1 METHODS

=head2 with_no_errors

=head2 with_no_errors_rs

    $resultset = $self->with_no_errors;
            or
    # to always return a Result-Set regardless of context,
    # this is useful when using in a TT document
    ( $resultset ) = $self->with_no_errors_rs;

Returns a Result-Set where the 'error_was_thrown' field is FALSE.

=cut

sub with_no_errors {
    my $self = shift;
    return $self->search( { error_was_thrown => 0 } );
}

sub with_no_errors_rs {
    my $self = shift;

    # use scalar to force a Result-Set to be returned
    return scalar( $self->with_no_errors );
}

1;

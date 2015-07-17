package XTracker::Schema::ResultSource::Public::GenerationCounter;
use strict;
use warnings;

use base 'DBIx::Class::ResultSource::Table';

use XTracker::Database::GenerationCounters qw(
    increment_generation_counters
    get_generation_counters
    generations_have_changed
    get_changed_generation_counters
);

=head1 NAME

XTracker::Schema::ResultSource::Public::GenerationCounter - DBIC resultset

=head1 DESCRIPTION

This class provides a DBIC wrapper for reading the generation counters
updated by L<XTracker::Database::GenerationCounters>.

=head1 METHODS

=head2 get_counters(@names)

Returns a reference to a hash with the current value of counters for
the specified C<@names>.

=cut

sub get_counters {
    my ($self, @names) = @_;

    return $self->storage->dbh_do(sub {
        my (undef, $dbh) = @_;
        return get_generation_counters($dbh, @names);
    });
}

=head2 have_changed($current_values)

Returns a boolean indicating whether any of the counters previously
returned from L</get_counters> or L</increment_counters> have changed.

=cut

sub have_changed {
    my ($self, $current) = @_;

    return $self->storage->dbh_do(sub {
        my (undef, $dbh) = @_;
        return generations_have_changed($dbh, $current);
    });
}

sub get_changed {
    my ($self, $current) = @_;

    return $self->storage->dbh_do(sub {
        my (undef, $dbh) = @_;
        return get_changed_generation_counters($dbh, $current);
    });
}

=head2 increment_counters(@names)

Increments the named generation counters and returns a reference to a
hash with the new values.  Must be done inside a transaction.

=cut

sub increment_counters {
    my ($self, @names) = @_;

    return $self->storage->dbh_do(sub {
        my (undef, $dbh) = @_;
        return increment_generation_counters($dbh, @names);
    });
}

1;

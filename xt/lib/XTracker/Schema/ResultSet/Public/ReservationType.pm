package XTracker::Schema::ResultSet::Public::ReservationType;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Public::ReservationType

=head1 METHODS

=head2 list_by_sort_order

Return the Reservation Types using the 'sort_order' field to sort them.

=cut

sub list_by_sort_order {
    my $self    = shift;


    return $self->search(
        { is_active => 't' },
        { order_by => 'sort_order ASC' },
    );
}

sub list_alphabetically {
    my $self    = shift;

    return $self->search(
        { is_active => 't'},
        { order_by => 'type ASC' },
    );
}

1;

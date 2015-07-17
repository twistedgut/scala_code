package XTracker::Schema::ResultSet::Public::ReservationSource;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Public::ReservationSource

=head1 METHODS

=head2 list_by_sort_order

Return the Reservation Sources using the 'sort_order' field to sort them.

=cut

sub list_by_sort_order {
    my $self    = shift;

    return $self->search(
        {},
        { order_by => 'sort_order ASC' },
    );
}

sub active_list_by_sort_order {
    my $self = shift;

    return $self->search({ is_active => 't'})->list_by_sort_order;

}

sub list_alphabetically {
    my $self    = shift;

    return $self->search(
        { is_active => 't'},
        { order_by  => 'source ASC' },
    );
}

1;

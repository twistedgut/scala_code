package XTracker::Schema::ResultSet::Public::ReservationStatus;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw( :reservation_status );

=head1 NAME

XTracker::Schema::ResultSet::Public::ReservationStatus

=head1 METHODS

=head2 non_uploaded

Get reservation statuses that are not uploaded ordered by id.

=cut

sub non_uploaded {
    return $_[0]->search(
        { id => { q{!=} => $RESERVATION_STATUS__UPLOADED } },
        { order_by => 'id' },
    );
}

1;

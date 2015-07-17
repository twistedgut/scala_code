package XTracker::Schema::ResultSet::Public::ReturnDelivery;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub search_by_date {

    my ( $resultset, $start, $end ) = @_;

    my $return_delivery_rs = $resultset->search(
        {
            'me.confirmed'      => 1,
            'me.date_confirmed' => { between => [ $start, $end ] },
        },
        {
            order_by => [ 'me.date_confirmed desc', ],
            prefetch => [ 'return_arrivals', 'operator', ],
        },
    );

    return $return_delivery_rs;
}

=head2 get_unconfirmed_return_deliveries

Returns all unconfirmed return deliveries, ordered by id

=cut

sub filter_unconfirmed {
    my ($self) = @_;

    return $self->search( { confirmed => 0 },
                          { order_by  => 'id DESC'} )->all;
}

1;

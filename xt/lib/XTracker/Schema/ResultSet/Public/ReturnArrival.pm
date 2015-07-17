package XTracker::Schema::ResultSet::Public::ReturnArrival;
# vim: ts=4 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Carp;

use base 'XTracker::Schema::ResultSetBase';

=head2 get_returns_arrived

    $array_ref  = $self->get_returns_arrived;

Returns a list of data for the 'Goods In -> Returns In' page.

=cut

sub get_returns_arrived {
     my ($self, $page) = @_;
     return $self->search(
        {
            'return_delivery.confirmed' => 1,
            'me.removed'                => 0,
            'me.goods_in_processed'     => 0,
        },
        {
            '+select'   => [ qw( orders.id orders.order_nr ) ],
            '+as'       => [ qw( order_id order_nr ) ],
            join => [
                'return_delivery',
                { 'link_return_arrival__shipments' => { shipment => { 'link_order__shipment' => 'orders' } }},
            ],
            page => $page,
            rows => 50,
            order_by => 'me.date ASC',
        }
    );
}

=head2 find_by_awb($awb) : $dbic_row|undef

Find the return arrival for the given awb.

=cut

sub find_by_awb {
    my ( $self, $awb ) = @_;
    croak 'You need to provide an air waybill' unless $awb;
    return $self->find($awb, { key => 'return_arrival_return_airway_bill_key' });
}

1;

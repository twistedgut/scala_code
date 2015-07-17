package XTracker::Schema::ResultSet::Public::RenumerationItem;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head1 NAME

XTracker::Schema::ResultSet::Public::RenumerationItem

=head1 METHODS

=head2 find_by_shipment_item( $shipment_item )

Search the ResultSet by shipment item, given a Public::ShipmentItem object or
a shipment item id.

    my $shipment_item = $schema->resultset('Public::ShipmentItem')
        ->find( $shipment_item_id );
    my $renumeration_items = $schema->resultset('Public::RenumerationItem')
        ->find_by_shipment_item( $shipment_item );

    # .. OR ..

    my $renumeration_items = $schema->resultset('Public::RenumerationItem')
        ->find_by_shipment_item( $shipment_item_id );

=cut

sub find_by_shipment_item {
    my ($self, $si) = @_;

    $si = $si->id if ref $si;

    return $self->search({
      'shipment_item_id' => $si
    })->first;
}

=head2 order_by_id

Orders the ResultSet by the C<id> column.

=cut

sub order_by_id {
    my $self = shift;

    return $self->search( undef, {
        order_by => 'id',
    } );

}

1;

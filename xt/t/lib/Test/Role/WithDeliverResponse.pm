package Test::Role::WithDeliverResponse;

use NAP::policy 'role';

use XTracker::Constants::FromDB qw(
    :prl_delivery_destination
);
use XTracker::Constants qw(
    :prl_type
);

use vars qw/
    $PRL_DELIVERY_DESTINATION__GOH_DIRECT
/;

=head1 NAME

Test::Role::WithDeliverResponse

=head1 DESCRIPTION

Role to be consumed by test class if they need extra logic about dealing
with deliver response messages.

=head1 METHODS

=head2 deliver_response_payload ($allocation_row, $args) : $deliver_response_message

Creates the data for a deliver_response message for the allocation supplied. Uses
the GOH direct lane as the default destination if none is supplied.

=cut

sub deliver_response_payload {
    my ($self, $allocation, $args) = @_;

    $args->{destination_id} //= $PRL_DELIVERY_DESTINATION__GOH_DIRECT;

    my $prl_delivery_destination = $self->schema->resultset('Public::PrlDeliveryDestination')->find(
        $args->{destination_id}
    );
    my $now = $self->schema->db_now()->strftime('%FT%T%z');
    my @item_details = my @items = map {
        {
            sku          => $_->variant->sku,
            delivered_at => $now,
            destination  => $prl_delivery_destination->message_name,
        }
    } $allocation->shipment->shipment_items;

    return {
        allocation_id => $allocation->id,
        item_details  => \@item_details,
        success       => $PRL_TYPE__BOOLEAN__TRUE,
        reason        => '',
        prl           => $allocation->prl->amq_identifier,
    };

}

=head2 get_delivery_destination( $id ) : $prl_delivery_destination_row

For given ID return record from prl_delivery_destination table.

=cut

sub get_delivery_destination {
    my ($self, $id) = @_;

    $self->schema
        ->resultset('Public::PrlDeliveryDestination')
        ->find($id);
}

package XT::Data::Fulfilment::Putaway::Container;
use NAP::policy "tt", "class";
extends "XT::Data::Fulfilment::Putaway";

=head1 NAME

XT::Data::Fulfilment::Putaway::Container - Putaway Cancelled using Container

=cut

sub marked_for_putaway_user_message {
    my ($self, $container_id) = @_;
    return "Tote $container_id marked for put away. Please place tote in put away area";
}

sub send_cancelled_shipment_item_to_putaway {
    my ($self, $shipment_item_row, $operator_row) = @_;
    $shipment_item_row->cancel_and_move_stock_to_iws_location_and_notify_pws(
        $operator_row->id,
    );
}


package XT::Data::Fulfilment::Putaway::Location;
use NAP::policy "tt", "class";
extends "XT::Data::Fulfilment::Putaway";

=head1 NAME

XT::Data::Fulfilment::Putaway::Location - Putaway Cancelled using Location

=cut

sub marked_for_putaway_user_message {
    my ($self, $container_id) = @_;
    return "Please place all items from tote $container_id in the 'Cancelled-to-Putaway' location, these items are now ready for putaway";
}

sub send_cancelled_shipment_item_to_putaway {
    my ($self, $shipment_item_row, $operator_row) = @_;
    $shipment_item_row->move_stock_to_cancelled_location( $operator_row );
}


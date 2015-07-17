
=head1 NAME

Test::XT::Fulfilment::Putaway::Location - Putaway Cancelled using Location

=cut

package Test::XT::Fulfilment::Putaway::Location;
use NAP::policy "tt", "test", "class";
extends "Test::XT::Fulfilment::Putaway";

use XTracker::Constants::FromDB qw(
    :shipment_item_status
);




has "+expected_cancel_status" => (
    # PRL - Cancel pending, moved to Cancelled-to-Putaway Location,
    # waiting to be carried to Putaway
    default => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
);

has "+expected_location_row"  => (
    default => sub {
        my $self = shift;
        $self->schema->resultset("Public::Location")->get_cancelled_location;
    },
);

sub flow_mech__fulfilment__packing_scanoutpeitem {
    my ($self, $container_id, $sku) = @_;

    my $cancelled_location_row = $self->schema->resultset(
        "Public::Location",
    )->get_cancelled_location();

    my $variant_rs = $self->schema->resultset("Public::Variant");
    my $variant_row = $variant_rs->find_by_sku($sku);
    my $initial_quantity = $cancelled_location_row->get_quantity_sum([
        $variant_row->id,
    ]);

    $self->flow->flow_mech__fulfilment__packing_scanoutpeitem_location(
        $cancelled_location_row->location,
    );

    # Test that it got into the Location
    my $quantity_increase = $cancelled_location_row->get_quantity_sum([
        $variant_row->id,
    ]) - $initial_quantity;
    is(
        $quantity_increase,
        1,
        "Found the added SKU($sku) in the Cancelled location",
    );
}

sub user_message__marked_for_putaway {
    my ($self, $container_row) = @_;
    my $container_id = $container_row->id;
    return "Please place all items from tote $container_id in the 'Cancelled-to-Putaway' location, these items are now ready for putaway";
}


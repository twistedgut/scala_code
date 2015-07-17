
=head1 NAME

Test::XT::Fulfilment::Putaway::Container - Putaway Cancelled using Container

=head1 DESCRIPTION

Note: this might also put it into a location i.e. the IWS location.

=cut

package Test::XT::Fulfilment::Putaway::Container;
use NAP::policy "tt", "class";
extends "Test::XT::Fulfilment::Putaway";
with "Test::Role::WithRolloutPhase";

use XTracker::Constants::FromDB qw(
    :shipment_item_status
);




has "+expected_cancel_status" => (
    default => sub {
        my $self = shift;
        $self->iws_rollout_phase
            # IWS - Cancelled immediately and brought back into the
            # IWS Location in the same Container
            ? $SHIPMENT_ITEM_STATUS__CANCELLED
            # Manual DC2 - Cancel Pending, left in Container to be
            # carried to the warehouse for manual stock adjust using
            # /StockControl/Cancellations
            : $SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
    },
);
has "+expected_location_row"  => (
    default => sub {
        my $self = shift;
        $self->iws_rollout_phase or return undef;
        $self->schema->resultset("Public::Location")->get_iws_location;
    },
);

sub flow_mech__fulfilment__packing_scanoutpeitem {
    my ($self, $container_id, $sku) = @_;

    $self->flow->flow_mech__fulfilment__packing_scanoutpeitem_tote(
        $container_id,
    );
}

sub user_message__marked_for_putaway {
    my ($self, $container_row) = @_;
    my $container_id = $container_row->id;
    return "Tote $container_id marked for put away. Please place tote in put away area";
}


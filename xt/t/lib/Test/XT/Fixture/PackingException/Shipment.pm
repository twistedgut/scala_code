package Test::XT::Fixture::PackingException::Shipment;
use NAP::policy "tt", "class","test";
extends "Test::XT::Fixture::Common::Shipment";
with "Test::Role::WithSchema";

=head1 NAME

Test::XT::Fixture::PackingException::Shipment.pm - Test fixture

=head1 DESCRIPTION

Test fixture with a Shipment that can be picked, cancelled, etc.

Feel free to add more transformations here.

=cut


use Test::More;

use XTracker::Constants::FromDB qw/
    :allocation_item_status
    :allocation_status
    :authorisation_level
    :packing_exception_action
    :shipment_item_status
    :shipment_status
/;
use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;

use XTracker::Database::Container qw/ get_commissioner_name /;

use Test::XT::Flow;


has "+flow" => (
    default => sub {
        my $self = shift;
        my $flow = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Feature::AppMessages',
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Flow::CustomerCare',
                'Test::XT::Flow::PRL',
            ],
            dbh => $self->schema->storage->dbh,
        );

        return $flow;
    }
);

has "+pid_count" => (
    default => 2,
);

=head2 missing_shipment_item_row() :

Created by ->with_missing_item()

=cut

has missing_shipment_item_row => (
    is         => "ro",
    lazy_build => 1,
);
sub _build_missing_shipment_item_row {
    my $self = shift;
    my $shipment_row = $self->shipment_row;

    # Happens at packing
    $shipment_row->update({ shipment_status_id => $SHIPMENT_STATUS__HOLD });

    # Happens in
    # XTracker::Order::Fulfilment::CheckShipmentException->_missing_item
    # Needs to be ordered by allocation_id?
    my $missing_shipment_item_row = $shipment_row->shipment_items->first;
    $missing_shipment_item_row->update_status(
        $SHIPMENT_ITEM_STATUS__NEW,
        $APPLICATION_OPERATOR_ID,
        $PACKING_EXCEPTION_ACTION__MISSING,
    );
    return $missing_shipment_item_row;
}

# After ->with_reallocated_missing_item()
has reallocated_allocation_row => (
    is         => "ro",
    lazy_build => 1,
);
sub _build_reallocated_allocation_row {
    my ($self) = @_;

    note "Shipment goes off hold";
    my $shipment_row = $self->shipment_row;
    XTracker::Database::Shipment::update_shipment_status(
        $self->schema->storage->dbh,
        $shipment_row->id,
        $SHIPMENT_STATUS__PROCESSING,
        $APPLICATION_OPERATOR_ID,
    );
    $shipment_row->discard_changes();

    note "Allocate response -- new allocation is allocated";
    my $missing_shipment_row = $self->missing_shipment_item_row->shipment;
    my $reallocated_allocation_row = $missing_shipment_row->allocations->search({
        status_id => $ALLOCATION_STATUS__REQUESTED,
    })->first;
    $reallocated_allocation_row->update_status(
        $ALLOCATION_STATUS__ALLOCATED,
        $APPLICATION_OPERATOR_ID,
    );
    my $reallocated_allocation_item_row
        = $reallocated_allocation_row->allocation_items->first;
    $reallocated_allocation_item_row->update_status(
        $ALLOCATION_ITEM_STATUS__ALLOCATED,
        $APPLICATION_OPERATOR_ID,
    );

    return $reallocated_allocation_row;
}



sub with_logged_in_user {
    my $self = shift;
    $self->flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Customer Care/Customer Search',
            'Customer Care/Order Search',
            'Fulfilment/Selection',
            'Fulfilment/Picking',
            'Fulfilment/Packing',
            'Fulfilment/Packing Exception',
            'Fulfilment/Commissioner',
            'Fulfilment/Induction',
        ]},
        dept => 'Customer Care'
    });
    return $self;
}

sub with_cancelled_order {
    my $self = shift;
    $self->flow->task__mech__cancel_order( $self->order_row );
    return $self;
}

sub with_picked_container_in_commissioner {
    my $self = shift;

    $self->picked_container_row->discard_changes();
    $self->picked_container_row->update({
        place             => get_commissioner_name(),
        pack_lane_id      => undef,
        pack_lane_id      => undef,
        routed_at         => undef,
        arrived_at        => undef,
        has_arrived       => undef,
        physical_place_id => undef,
    });

    return $self;
}

=head2 with_missing_item() : $self

Missing at packing, on hold, confirmed at Packing Exception.

=cut

sub with_missing_item {
    my $self = shift;
    $self->missing_shipment_item_row();
    return $self;
}

=head2 with_reallocated_missing_item() : $self

Taken off hold, reallocated.

=cut

sub with_reallocated_missing_item {
    my $self = shift;
    $self->reallocated_allocation_row();
    return $self;
}

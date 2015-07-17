package Test::XT::Fixture::Route::Container;
use NAP::policy "tt", "class";
with "XTracker::Role::WithSchema";


=head1 NAME

Test::XT::Fixture::Route::Container - Container fixture

=head1 DESCRIPTION

Fixture class for a Container and possibly ShipmentItems in it.

=cut

use Test::XTracker::Data;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;

has container_id => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my ($container_id) = Test::XT::Data::Container->create_new_containers();
        return $container_id;
    },
);

has container_row => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->schema->resultset("Public::Container")->find($self->container_id);
    },
);

has shipment_row => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;

        # Crate Shipment
        my($channel,$pids) = Test::XTracker::Data->grab_products({
            channel  => "NAP",
            how_many => 1,
        });
        my $shipment_row = Test::XTracker::Data->create_domestic_order(
            channel => $channel,
            pids    => $pids,
        )->shipments->first;

        return $shipment_row;
    },
);

sub BUILD {
    my $self = shift;
    # Touch the lazy attributes to construct them
    $self->container_row;
    $self->shipment_row;
}

sub with_shipment_in_container {
    my $self = shift;

    # Place the Items in the Container
    for my $shipment_item_row ($self->shipment_row->shipment_items) {
        $shipment_item_row->pick_into(
            $self->container_id,
            $APPLICATION_OPERATOR_ID,
            { dont_validate => 1 },
        );
    }

    return $self;
}

sub with_shipment_on_hold {
    my $self = shift;

    $self->shipment_row->hold_for_prepaid_reason({
        comment     => "On hold for test",
        operator_id => $APPLICATION_OPERATOR_ID,
    });

    return $self;
}

sub discard_changes {
    my $self = shift;
    $_->discard_changes for(
        $self->container_row,
    );
}


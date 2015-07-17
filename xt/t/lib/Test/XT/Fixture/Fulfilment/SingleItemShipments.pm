package Test::XT::Fixture::Fulfilment::SingleItemShipments;
use NAP::policy "tt", "class";
with (
    "Test::Role::WithSchema",
    "Test::XT::Fixture::Role::WithProduct",
);

=head1 NAME

Test::XT::Fixture::Fulfilment::SingleItemShipments - Test fixture

=head1 DESCRIPTION

Test fixture with three single-item Shipments, which can be picked
into a single Container.

=cut

use Test::More;

use Test::XT::Data;
use Test::XT::Data::Container;



=head1 ATTRIBUTES

=cut

has flow => (
    is       => "ro",
    default => sub {
        my $self = shift;
        return Test::XT::Data->new_with_traits(
            traits => [
                "Test::XT::Data::Order",
                "Test::XT::Flow::PRL",
            ],
            dbh    => $self->schema->storage->dbh,
        );
    }
);

has order_count => (
    is      => "ro",
    default => 3,
);

has "+pid_count" => (
    is      => "ro",
    default => 1, # single-item shipments (pids_multiplicator is also 1)
);

has order_rows => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return [
            map {
                my $order_info = $self->flow->new_order(
                    products => $self->pids,
                );
                $order_info->{order_object}
            } 1 .. $self->order_count,
        ];
    },
);

has shipment_rows => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return [ map { $_->shipments->first } @{$self->order_rows} ];
    },
);

has picked_container_id => (
    is      => "rw",
    trigger => sub { shift->clear_picked_container_row },
);

has picked_container_row => (
    is      => "rw",
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->schema->find( Container => $self->picked_container_id );
    },
    clearer => "clear_picked_container_row",
);


=head1 METHODS

=cut

sub BUILD {
    my $self = shift;
    note "*** BEGIN SingleItemShipmentss Fixture setup " . ref($self);

    $self->shipment_rows;

    note "*** END SingleItemShipmentss Fixture setup " . ref($self);
}

sub discard_changes { }

sub with_allocated_shipments {
    my $self = shift;

    for my $shipment_row (@{$self->shipment_rows}) {
        Test::XTracker::Data::Order->allocate_shipment( $shipment_row );
    }

    return $self;
}

sub with_selected_shipments {
    my $self = shift;

    $self->with_allocated_shipments();
    for my $shipment_row (@{$self->shipment_rows}) {
        Test::XTracker::Data::Order->select_shipment( $shipment_row );
    }

    return $self;
}

sub with_picked_shipments {
    my $self = shift;

    $self->with_selected_shipments();

    # A Shipment (really an Allocation) can go to Picked either directly
    # from Selected, or via Staged. In this case we select it, then pick
    # it to avoid that extra step.
    my $container_id = Test::XT::Data::Container->get_unique_id();

    for my $shipment_row (@{$self->shipment_rows}) {
        Test::XTracker::Data::Order->pick_shipment(
            $shipment_row,
            $container_id,
        );
    }

    $self->picked_container_id($container_id);

    return $self;
}

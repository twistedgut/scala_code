package Test::XT::Fixture::Route::ShipmentInBox;
use NAP::policy "tt", "class";
with "XTracker::Role::WithSchema";


=head1 NAME

Test::XT::Fixture::Route::ShipmentInBox - Box and Shipment fixture

=head1 DESCRIPTION

Shipment packed into a Box, possibly with the Box placed in a
Container.

=cut

use Test::XTracker::Data;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw/ :shipment_type /;

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

has shipment_box_row => (
    is => "ro",
    lazy => 1,
    default => sub {
        my $self = shift;
        $self->shipment_row->create_related(
            shipment_boxes => {
                box_id  => $self->_find_outer_box->id,
                tote_id => "", # Can't be null, awesome
            },
        );
    },
);

sub _find_outer_box {
    my $self = shift;
    return $self->schema->resultset("Public::Box")->search({
        box => { -like => "Outer%" },
    })->first;
}

sub BUILD {
    my $self = shift;
    # Touch the lazy attributes to construct them
    $self->shipment_box_row;
}

sub with_box_in_container {
    my $self = shift;

    $self->shipment_box_row->update({ tote_id => "abc" });
    $self->discard_changes();

    return $self;
}

sub with_shipment_is_premier {
    my $self = shift;

    $self->shipment_row->update({
        shipment_type_id => $SHIPMENT_TYPE__PREMIER,
    });
    $self->discard_changes();

    return $self;
}

sub with_shipment_real_time_carrier_booking {
    my $self = shift;

    $self->shipment_row->update({ real_time_carrier_booking => 1 });
    $self->discard_changes();

    return $self;
}

sub discard_changes {
    my $self = shift;
    $_->discard_changes for(
        $self->shipment_box_row,
        $self->shipment_row,
    );
}


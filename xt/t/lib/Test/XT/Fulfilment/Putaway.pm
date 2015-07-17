
=head1 NAME

Test::XT::Fulfilment::Putaway - Putaway Cancelled using either a Container or a Location

=head1 DESCRIPTION

See L<XT::Data::Fulfilment::Putaway> for details about the domain,
which subclass will be used according to the config, etc.

=cut

package Test::XT::Fulfilment::Putaway;
use NAP::policy "tt", qw( test class );
with "Test::Role::WithSchema";
use Module::Runtime 'use_module';
use List::MoreUtils qw/ uniq /;

use XTracker::Config::Local qw(
    putaway_intransit_type
);
use XTracker::Constants::FromDB qw(
    :shipment_item_status
);


use Carp;

has flow => ( is => "ro", required => 1 );

has expected_cancel_status => (is => "ro");
has expected_location_row  => (is => "ro");

has initial_location_quantity => (
    is      => "ro",
    lazy    => 1,
    default => sub { shift->location_quantity() },
);

has shipment_row => ( is => "ro" );

sub new_by_type {
    my $class = shift;
    return use_module(__PACKAGE__ . "::" . putaway_intransit_type())->new(@_);
}

sub BUILD {
    my $self = shift;
    # Set lazy default after object is fully created
    $self->initial_location_quantity() if $self->shipment_row;
}

sub ensure_shipment_row {
    my $self = shift;
    $self->shipment_row
        or confess(ref($self) . " object not initialized with a ->shipment_row");
}

sub location_quantity {
    my $self = shift;
    $self->ensure_shipment_row();
    $self->expected_location_row or return 0;

    my $shipment_items_rs = $self->shipment_row->shipment_items;
    my $variant_ids = [ uniq map { $_->variant_id } $shipment_items_rs->all ];
    return $self->expected_location_row->get_quantity_sum( $variant_ids );
}

sub test_shipment_items_status {
    my $self = shift;
    $self->ensure_shipment_row();

    my $shipment_items_rs = $self->shipment_row->shipment_items;
    for my $shipment_item_row( $shipment_items_rs->all ) {
        is(
            $shipment_item_row->shipment_item_status_id,
            $self->expected_cancel_status,
            "ShipmentItem status is cancelled/cancel_pending (" . $self->expected_cancel_status . ")",
        );
    }
}

sub test_quantities_moved_to_location {
    my $self = shift;
    $self->ensure_shipment_row();
    $self->expected_location_row or return;

    my $added_location_quantity
        = $self->location_quantity() - $self->initial_location_quantity;
    my $shipment_items_rs = $self->shipment_row->shipment_items;
    is(
        $added_location_quantity,
        scalar $shipment_items_rs->all,
        "The quantities were moved from the container to the Location (" . $self->expected_location_row->location . ")",
    );
}

sub flow_mech__fulfilment__packing_scanoutpeitem {
    my ($self, $container_id, $sku) = @_;
    croak("Abstract");
}

sub user_message__marked_for_putaway {
    my ($self, $container_row) = @_;
    croak("Abstract");
}

sub test_user_message__marked_for_putaway {
    my ($self, $container_row) = @_;
    my $mech = $self->flow->mech;
    $mech->has_feedback_info_ok(
         $self->user_message__marked_for_putaway($container_row),
    ) or diag($mech->content);
}



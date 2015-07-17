package XT::Data::PRL::Conveyor::Route::ToDispatch;
use NAP::policy "tt", "class";
with
    "XT::Data::PRL::Conveyor::Route::Role::SendMessage",
    "XTracker::Role::WithSchema";

=head1 NAME

XT::Data::PRL::Conveyor::Route::ToDispatch - A route to a Dispatch Lane

=head1 DESCRIPTION

This is a Route for a Box or Container (if the box is too small to be
conveyed on its own, it's placed in a Tote) from a Packing Station to
a Dispatch Lane, when Packing is complete.

=cut

use List::MoreUtils qw/ uniq /;
use Carp;

=head1 ATTRIBUTES

=cut

has shipment_box_row => (
    is       => "ro",
    required => 1,
);

has shipment_row => (
    is       => "ro",
    required => 1,
);

has has_carrier_automation => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return !! $self->shipment_row->is_carrier_automated();
    },
);

=head1 METHODS

=head2 send(%args) : $route_destination_name | undef | die

Send a routing message (if appropriate) with a destination that may or
may not depend on %args.

Return the name of the destination the the route messages was sent
for, or undef if no message was sent. Die on errors.

=cut

sub send {
    my ($self, $args) = @_;

    my $route_destination = $self->get_route_destination() or return undef;

    # Send for the Tote containing the box, if there is one
    my $container_string_id =
        $self->shipment_box_row->tote_id
        || $self->shipment_box_row->id;

    $self->send_message(
        $container_string_id,
        $route_destination,
    );

    return $route_destination;
}

=head2 get_route_destination($args) : $destination_name | undef

Return an actual destination name according to the Shipment in the
Containers, or undef if these Containers shouldn't be routed on the
Conveyor.

* To: Carton Sealer . Packing is complete and shipment ready for dispatch
** Carrier automated (implies UPS),
** Is not in a tote

* To: No routing (normally, it would go to the Premier Dispatch lane, see below)
** The shipment is premier
** NOTE: due to the layout of the warehouse, they don't want to convey
   the box all the way over to the Premier Dispatch Lane when the
   Premier delivery van is parked right next to the Premier Pack
   Lane. So they will just manually walk all the boxes over to the
   delivery van.

* To: Premier Lane
** Everything else
** NOTE: This would really be the the the manual_dispatch lane, but
   apparently that lane is too short, and they can't fit all the totes
   there. So we'll send "everyting else" to the premier_dispatch lane
   instead.
** NOTE: this should really have been solved by pointing
   manual_dispatch to that lane, but Dematic still refers to it as
   Premier, so we'll stick with that to keep the name uniform across
   systems.

=cut

sub get_route_destination {
    my ($self, $args) = @_;
    $self->can_be_carton_sealed and return "DispatchLanes/any_carton_sealer";
    $self->is_premier           and return undef;
    return                                 "DispatchLanes/premier_dispatch";
}

=head2 can_be_carton_sealed() : Bool

Return true if the Containers can be carton sealed, else false.

They can be carton sealed if it
    a) doesn't require extra paperwork
    b) isn't conveyed in a tote

=cut

sub can_be_carton_sealed {
    my $self = shift;
    return 0 if $self->requires_extra_paperwork;
    return 0 if $self->is_conveyed_in_tote;
    return 1;
}

=head2 requires_extra_paperwork() : Bool

Whether the Shipment requires extra paper work to be completed
before sealing the box.

This isn't necessary if the Shipment is Carrier Automated.

=cut

sub requires_extra_paperwork {
    my $self = shift;
    return 0 if $self->has_carrier_automation;
    return 1;
}

=head2 is_conveyed_in_tote() : Bool

Whether the Container is a small box located in a larger tote.

=cut

sub is_conveyed_in_tote {
    my $self = shift;
    return !! $self->shipment_box_row->tote_id;
}

=head2 is_premier() : Bool

Whether the Shipment is a Premier Shipment.

=cut

sub is_premier {
    my $self = shift;
    return !! $self->shipment_row->is_premier;
}


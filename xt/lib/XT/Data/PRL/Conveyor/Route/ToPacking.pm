package XT::Data::PRL::Conveyor::Route::ToPacking;
use NAP::policy "tt", "class";
with (
    "XT::Data::PRL::Conveyor::Route::Role::SendMessage",
    "XT::Data::PRL::Conveyor::Route::Role::WithContainers",
);

=head1 NAME

XT::Data::PRL::Conveyor::Route::ToPacking - A route to a Pack Lane

=head1 DESCRIPTION

This is a Route for a Container to a Pack Lane.


=head1 SYNOPSIS

    XT::Data::PRL::Conveyor::Route::ToPacking->new({
        container_id => $container_id,
    })->send();

=cut

use List::MoreUtils qw/ uniq /;

=head1 METHODS

=head2 get_route_destination($args) : $destination_name | undef

Return an actual destination name according to $args, or undef if
these Containers shouldn't be routed on the Conveyor.

Ask the Pack Lane Manager for a destination, unless any Shipment in
any Container is on hold (so make sure all these containers are
related by containing the same Shipment), in which case return undef.

=cut

sub get_route_destination {
    my ($self, $args) = @_;

    # If we have many Containers, they'll all go to the same, so just
    # look at the first PackLane destination
    my ($packlane) =
        # Sets pack_lane_id on Container, so we still have to loop
        # over all of them
        map { $_->choose_packlane() }
        @{$self->container_rows};

    return $packlane->get_packlane_description();
}

=head2 get_container_shipments() : @shipment_rows

Return distinct list of all the Shipments contained in the Containers.

=cut

sub get_container_shipments {
    my $self = shift;
    return uniq(
        map { $_->shipments } @{$self->container_rows()}
    );
}


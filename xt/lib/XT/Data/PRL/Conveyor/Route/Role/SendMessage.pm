package XT::Data::PRL::Conveyor::Route::Role::SendMessage;
use NAP::policy "tt", "role";

=head1 NAME

XT::Data::PRL::Conveyor::Route::Role::SendMessage - Send the Route message

=head1 DESCRIPTION

This is a Route for one or many Containers (or boxes or packages) on
the Conveyor belt which will make the Container end up in the right
place.

The right place depends on where the Container needs to go
(e.g. Dispatch, PackingException) and possibly what the Container
contains.

Notify the Conveyor that it should route the Container by calling
->send() with information about what it contains (this varies with the
destination).

Calling ->send() will send an AMQ message to the Conveyor belt with
the appropriate destination.

=cut

use Carp;

with 'XTracker::Role::WithAMQMessageFactory';
use XTracker::Config::Local "config_var";

has _prl_rollout_phase => (
    is      => "ro",
    isa     => "Int",
    default => sub { config_var("PRL", "rollout_phase") },
);


=head1 METHODS

=head2 new(%args) : $new_object | die

Create new Route object.

Create a Route of the correct sub class depending on which logical
destination the Container should go to. E.g.

    XT::Data::PRL::Conveyor::Route::ToPacking->new({ ... })->send({ ... });
    XT::Data::PRL::Conveyor::Route::ToDispatch->new({ ... })->send({ ... });


=head2 send_message($container_id, $route_destination) :

Send a routing message to $route_destination with $container_id (note:
this is the "container_id" string sent in the message, it may be a
container_id, box_id, whatever).

=cut

sub send_message {
    my ($self, $container_id, $route_destination) = @_;

    return unless $self->_prl_rollout_phase; # do not send messages if PRLs are off
    $self->msg_factory->transform_and_send(
        "XT::DC::Messaging::Producer::PRL::RouteRequest" => {
            container_id          => $container_id,
            container_destination => $route_destination,
        },
    );
}

=head2 display_route_destination($route_destination) : $display_string

Return a string version of $route_destination suitable for displaying
to the user.

E.g. "PackLane/pack_lane_1" returns "pack lane 1".

=cut

sub display_route_destination {
    my ($self, $route_destination) = @_;

    # e.g. "PackLane/pack_lane_1", or "PackingOperations/packing_exception"
    $route_destination =~ m|/(\w+)$| or return $route_destination;
    my $display_string = $1;
    $display_string =~ s/_/ /g;

    return $display_string;
}


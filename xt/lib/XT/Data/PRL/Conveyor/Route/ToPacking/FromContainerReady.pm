package XT::Data::PRL::Conveyor::Route::ToPacking::FromContainerReady;
use NAP::policy "tt", "class";
extends "XT::Data::PRL::Conveyor::Route::ToPacking";

=head1 NAME

XT::Data::PRL::Conveyor::Route::ToPacking::FromContainerReady - A route to a Pack Lane from ContainerReady

=head1 DESCRIPTION

This is a Route for a Container to a Pack Lane, but only when it's
routed from the receipt of the ContainerReady message.

Only some PRLs will route the Container at this point, e.g. Dematic
(DCD). All others will not do anything.

=cut

use MooseX::Params::Validate qw/validated_list/;
use Carp;

use XTracker::Config::Local qw/config_var/;

=head1 METHODS

=head2 get_route_destination( :$prl_amq_name ) : $destination_name | undef

Return an actual destination name according to the routing type and
%args, or undef if these Containers shouldn't be routed on the
Conveyor, e.g. depending on the $prl_amq_name (e.g. "Full",
"dcd").

Ask the Pack Lane Manager for a destination if the PRL should route at
this point, else return undef.

=cut

sub get_route_destination {
    my ($self,  $prl_amq_name ) = validated_list( \@_,
        prl_amq_name => { isa => "Str" },
    );

    # if container ready is for hook, do not route it anywhere
    return undef if $self->container_id->type eq 'hook';

    my $prl = XT::Domain::PRLs::get_prl_from_amq_identifier({
        amq_identifier => $prl_amq_name,
    });

    my $should_send_route_message = $prl->container_ready_requires_routing;

    $should_send_route_message or return undef;

    return $self->SUPER::get_route_destination();
}


package XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsAlreadyComplete;
use NAP::policy 'exception';

=head1 NAME

XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsAlreadyComplete

=head1 DESCRIPTION

Thrown if user tries to mark completed integration container as complete.

=head1 ATTRIBUTES

=head2 container_id

Container ID provided.

=cut

has container_id => (
    is       => 'ro',
    isa      => 'Str|NAP::DC::Barcode::Container::Tote',
    required => 1,
);

has '+message' => (
    default => q/Cannot mark container %{container_id}s complete as it is already completed/,
);

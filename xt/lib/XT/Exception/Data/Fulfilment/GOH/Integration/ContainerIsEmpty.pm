package XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsEmpty;
use NAP::policy 'exception';

=head1 NAME

XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsEmpty

=head1 DESCRIPTION

Thrown if user tries to mark empty integration container as complete.

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
    default => q/Cannot mark container %{container_id}s complete as it is empty/,
);

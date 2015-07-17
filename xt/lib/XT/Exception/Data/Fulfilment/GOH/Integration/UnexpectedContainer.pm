package XT::Exception::Data::Fulfilment::GOH::Integration::UnexpectedContainer;
use NAP::policy 'exception';

=head1 NAME

XT::Exception::Data::Fulfilment::GOH::Integration::UnexpectedContainer

=head1 DESCRIPTION

Thrown at GOH Integration point if user scan unexpected container.

=head1 ATTRIBUTES

=head2 container_id

Container ID provided.

=cut

has container_id => (
    is       => 'ro',
    isa      => 'Str|NAP::DC::Barcode::Container::Tote',
    required => 1,
);

=head2 required_container_id

Container ID required.

=cut

has required_container_id => (
    is       => 'ro',
    isa      => 'Str|NAP::DC::Barcode::Container::Tote',
    required => 1,
);

has '+message' => (
    default => q/Container %{container_id}s isn't the expected one (%{required_container_id}s)/,
);

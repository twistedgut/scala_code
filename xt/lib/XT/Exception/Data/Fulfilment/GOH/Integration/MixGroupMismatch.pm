package XT::Exception::Data::Fulfilment::GOH::Integration::MixGroupMismatch;
use NAP::policy 'exception';

=head1 NAME

XT::Exception::Data::Fulfilment::GOH::Integration::MixGroupMismatch

=head1 DESCRIPTION

Thrown at GOH Integration point if user scan SKU that has
different mix group than stock in integration container.

=head1 ATTRIBUTES

=head2 sku

SKU

=cut

has sku => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 container_id

COntainer ID

=cut

has container_id => (
    is       => 'ro',
    isa      => 'Str|NAP::DC::Barcode::Container::Tote',
    required => 1,
);

has '+message' => (
    default => q/Sku %{sku}s is not for the tote %{container_id}s. Try again or missing item./,
);

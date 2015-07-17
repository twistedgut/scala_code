package XT::Exception::Data::Fulfilment::GOH::Integration::AttemptToUseDCDContainerAtDirectLane;

use NAP::policy 'exception';

=head1 NAME

XT::Exception::Data::Fulfilment::GOH::Integration::AttemptToUseDCDContainerAtDirectLane

=head1 DESCRIPTION

Thrown at GOH Integration point if at Direct wlane user scan contianer that came from Dematic.

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
    default => q/Tote %{container_id}s from DCD is not expected at Direct Lane. Please take tote to Integration lane./,
);

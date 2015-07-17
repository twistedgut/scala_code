package XT::Exception::Data::Fulfilment::GOH::Integration::ScanRoutedContainer;

use NAP::policy 'exception';

=head1 NAME

XT::Exception::Data::Fulfilment::GOH::Integration::ScanRoutedContainer

=head1 DESCRIPTION

Thrown at GOH Integration point in case when user scans contianer that was just marked as complete.

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
    default => q/The tote %{container_id}s is already marked as complete at GOH Integration. Please place it on the conveyor to Packing./,
);

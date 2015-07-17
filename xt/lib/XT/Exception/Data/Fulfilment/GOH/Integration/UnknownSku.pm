package XT::Exception::Data::Fulfilment::GOH::Integration::UnknownSku;
use NAP::policy 'exception';

=head1 NAME

XT::Exception::Data::Fulfilment::GOH::Integration::UnknownSku

=head1 DESCRIPTION

Thrown at GOH Integration point if user scan unknown Sku, that is
one that could not be found on Direct/Integration lane (depending
on whith which lane  user is working).

=head1 ATTRIBUTES

=head2 sku

SKU

=cut

has sku => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 prl_delivery_destination_row

Prl delivery destination object where sku in question
was expected

=cut

has prl_delivery_destination_row => (
    is       => 'ro',
    isa      => 'XTracker::Schema::Result::Public::PrlDeliveryDestination',
    required => 1,
    handles  => {
        lane_name => 'name',
    },
);

has '+message' => (
    default => q/Sku %{sku}s is not expected to be at %{lane_name}s, please put onto Problem rail/,
);

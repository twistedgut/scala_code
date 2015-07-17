package XT::Exception::Data::Fulfilment::GOH::Integration::InvalidSkuBarcode;
use NAP::policy 'exception';

=head1 NAME

XT::Exception::Data::Fulfilment::GOH::Integration::InvalidSkuBarcode

=head1 DESCRIPTION

Thrown at GOH Integration point if user scan invalid SKU barcode.

=head1 ATTRIBUTES

=head2 sku

SKU

=cut

has sku => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has '+message' => (
    default => q/Scanned barcode %{sku}s is not a valid SKU./,
);

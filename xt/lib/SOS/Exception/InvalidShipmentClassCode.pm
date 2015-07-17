package SOS::Exception::InvalidShipmentClassCode;
use NAP::policy "tt", 'exception';

=head1 NAME

SOS::Exception::InvalidShipmentClassCode

=head1 DESCRIPTION

Thrown if a shipment class code is passed that can not be matched to a known shipment
class

=head1 ATTRIBUTES

=head2 shipment_class_code

Shipment class code that was passed

=cut
has 'shipment_class_code' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has '+message' => (
    default => q/No shipment class could be found with the code %{shipment_class_code}s/,
);

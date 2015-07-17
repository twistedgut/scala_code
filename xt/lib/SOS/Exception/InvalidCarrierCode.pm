package SOS::Exception::InvalidCarrierCode;
use NAP::policy "tt", 'exception';

=head1 NAME

SOS::Exception::InvalidCarrierCode

=head1 DESCRIPTION

Thrown if a carrier code is passed that can not be matched to a known carrier

=head1 ATTRIBUTES

=head2 carrier_code

Carrier code that was passed

=cut
has 'carrier_code' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has '+message' => (
    default => q/No carrier could be found with the code %{carrier_code}s/,
);

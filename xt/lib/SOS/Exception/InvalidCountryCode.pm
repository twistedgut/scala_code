package SOS::Exception::InvalidCountryCode;
use NAP::policy "tt", 'exception';

=head1 NAME

SOS::Exception::InvalidCountryCode

=head1 DESCRIPTION

Thrown if a country code is passed that can not be matched to a known country

=head1 ATTRIBUTES

=head2 country_code

Country code that was passed

=cut
has 'country_code' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has '+message' => (
    default => q/No country could be found with the code %{country_code}s/,
);

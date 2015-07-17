package SOS::Exception::InvalidRegionCode;
use NAP::policy "tt", 'exception';

=head1 NAME

SOS::Exception::InvalidRegionCode

=head1 DESCRIPTION

Thrown if a region code is passed that can not be matched to a known region within the
given country

=head1 ATTRIBUTES

=head2 country_code

Country code that was passed

=cut
has 'country_code' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head2 region_code

Region code that was passed

=cut
has 'region_code' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has '+message' => (
    default => q/No region could be found with the code %{region_code}s in the scope of
        country %{country_code}s/,
);

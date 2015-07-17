package NAP::XT::Exception::SOS::UnmappableCarrier;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::SOS::UnmappableCarrier

=head1 DESCRIPTION

Thrown if when attempting to match a shippable's carrier to the equivilent SOS code, no
 matching code could be found

=head1 ATTRIBUTES

=head2 carrier

Carrier that could not be matched

=cut

has 'carrier' => (
    is => 'ro',
    isa => 'XTracker::Schema::Result::Public::Carrier',
    required => 1,
);

sub _carrier_name {
    my ($self) = @_;
    return $self->carrier->name();
}

has '+message' => (
    default => q/Carrier with name '%{_carrier_name}s' could not be matched to a known SOS code'/,
);

1;

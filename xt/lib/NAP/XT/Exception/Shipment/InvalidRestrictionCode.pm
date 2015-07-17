package NAP::XT::Exception::Shipment::InvalidRestrictionCode;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::Shipment::InvalidRestrictionCode

=head1 DESCRIPTION

Thrown if an attempt is made to add or remove one or more unknown shipping-restriction codes

=head1 ATTRIBUTES

=head2 unknown_codes

ArrayRef of unknown shipping restriction codes

=cut

has 'unknown_codes' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1,
);

sub _code_string {
    my ($self) = @_;
    return join(', ', @{$self->unknown_codes()} );
}

has '+message' => (
    default => q/The following shipping-restriction codes are unknown: %{_code_string}s./,
);

1;

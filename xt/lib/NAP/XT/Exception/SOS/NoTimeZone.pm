package NAP::XT::Exception::SOS::NoTimeZone;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::SOS::NoTimeZone

=head1 DESCRIPTION

Thrown when no time-zone can be derived from any of the shippable's datetime objects

=cut

has '+message' => (
    default => q/No time-zone could be derived'/,
);

1;

package NAP::XT::Exception::SOS::IncompatibleShippable;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::SOS::IncompatibleShippable

=head1 DESCRIPTION

Thrown when an attempt is made to make an SLA request to SOS with a shippable that
is not compatible with the current SOS configuration

(e.g. it has nominated day data when XT has been configured not to use SOS for
nominated day shipments)

=cut

has '+message' => (
    default => q/This shippable is not compatible with the current SOS configuration'/,
);

1;

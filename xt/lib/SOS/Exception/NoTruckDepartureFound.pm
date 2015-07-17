package SOS::Exception::NoTruckDepartureFound;
use NAP::policy "tt", 'exception';

=head1 NAME

SOS::Exception::NoTruckDepartureFound

=head1 DESCRIPTION

Thrown if no truck departure could be found for a shipment

=cut

has '+message' => (
    default => q/No truck departure could be found/,
);

package SOS::TruckDepartureEvent;
use NAP::policy 'tt', 'class';
use DateTime;

=head1 NAME

SOS::TruckDepartureEvent

=head1 DESCRIPTION

An object representing a specific truck departure event

=cut

has 'carrier' => (
    is  => 'ro',
    isa => 'XTracker::Schema::Result::SOS::Carrier',
);

has 'shipment_class_rows' => (
    is  => 'ro',
    isa => 'ArrayRef[XTracker::Schema::Result::SOS::ShipmentClass]',
);

has 'departure_time' => (
    is  => 'ro',
    isa => 'DateTime',
);

=head2 as_calendar_event

Returns a hashref representation of a calendar event for this event object

=cut

sub as_calendar_event {
    my ( $self ) = @_;

    my $event = {
        carrier     => $self->carrier->name,
        departure_time  => $self->departure_time->strftime("%Y-%m-%dT%H:%M:%S%z"),
    };

    return $event;
}

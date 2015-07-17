package SOS::Exception::NoNDSelectionTime;
use NAP::policy "tt", 'exception';

=head1 NAME

SOS::Exception::NoNDSelectionTime

=head1 DESCRIPTION

Thrown if no nominated day selection time is available for a given comination of
 carrier and shipment_class

=head1 ATTRIBUTES

=head2 carrier

Carrier that was searched against

=cut
has 'carrier' => (
    is => 'ro',
    isa => 'XTracker::Schema::Result::SOS::Carrier',
    required => 1,
);
sub _carrier_name {
    my ($self) = @_;
    return $self->carrier->name();
}

=head2 shipment_class

Shipment class that was searched against

=cut
has 'shipment_class' => (
    is => 'ro',
    isa => 'XTracker::Schema::Result::SOS::ShipmentClass',
    required => 1,
);
sub _class_name {
    my ($self) = @_;
    return $self->shipment_class->name();
}

has '+message' => (
    default => q/No nominated day selection time is available for shipments of class %{_class_name}s delivered by carrier %{_carrier_name}s'/,
);

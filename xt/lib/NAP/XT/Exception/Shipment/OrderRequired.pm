package NAP::XT::Exception::Shipment::OrderRequired;
use NAP::policy 'tt', 'exception';

=head1 NAME

NAP::XT::Exception::Shipment::OrderRequired

=head1 DESCRIPTION

Thrown if code is run on a shipment where it expects it to have an associated order
 but it doesn't have one

=head1 ATTRIBUTES

=head2 shipment

Shipment that has no order (but should)

=cut

has 'shipment' => (
    is => 'ro',
    isa => 'XTracker::Schema::Result::Public::Shipment',
    required => 1,
);

sub _shipment_id {
    my ($self) = @_;
    return $self->shipment->id();
}

has '+message' => (
    default => q/Shipment %{_shipment_id}s is missing an associated order/,
);

1;

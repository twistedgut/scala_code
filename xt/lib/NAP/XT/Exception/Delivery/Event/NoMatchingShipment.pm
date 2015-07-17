package NAP::XT::Exception::Delivery::Event::NoMatchingShipment;
use NAP::policy qw/exception/;

=head1 NAME

NAP::XT::Exception::Delivery::Event::NoMatchingShipment

=head1 DESCRIPTION

Error thrown if an attempt is made to create a new XTracker::Delivery::Event object, but
    no existing shipment can be identified from the data provided

=cut

has order_number => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has waybill_number => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has '+message' => (
    default => 'No shipment could be identified to match order_number: %{order_number}s'
        . ' and waybill_number: %{waybill_number}s',
);

package NAP::XT::Exception::Delivery::Event::UnknownEventType;
use NAP::policy qw/exception/;

=head1 NAME

NAP::XT::Exception::Delivery::Event::UnknownEventType

=head1 DESCRIPTION

Error thrown if an attempt is made to create a new XTracker::Delivery::Event object, but
    the given delivery-event-type is unknown

=cut

has event_type => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has '+message' => (
    default => 'The delivery-event-type: "%{event_type}s" is unknown',
);

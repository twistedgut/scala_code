package XT::DC::Messaging::Consumer::Shipment;
use NAP::policy qw/class/;

extends 'NAP::Messaging::Base::Consumer';

use XTracker::Delivery::Event;
use XTracker::Logfile qw( xt_logger );
use DateTime::Format::DateParse;
use XT::DC::Messaging::Spec::Shipment;

sub routes {
    return {
        destination => {
            'sos-delivery-event' => {
                code => \&delivery_event,
                spec => XT::DC::Messaging::Spec::Shipment->delivery_event(),
            },
        },
    };
}

sub delivery_event {
    my ( $self, $message, $headers ) = @_;

    my $return = 1;

    try {
        my $delivery_event = XTracker::Delivery::Event->new({
            waybill_number      => $message->{waybill_number},
            order_number        => $message->{order_number},
            sos_event_type      => $message->{event_type},
            event_happened_at   => DateTime::Format::DateParse->parse_datetime(
                $message->{event_happened_at}
            ),
        });

        $delivery_event->log_in_database();
    } catch {
        my $exception = $_;

        if (ref($exception) eq 'NAP::XT::Exception::Delivery::Event::NoMatchingShipment') {
            # Unfortunately we expect to get alot of these :/ as the customer-context
            # data we historically send through to the carriers does not contain enough
            # information for SOS to filter out all irrelevant events, and also to be able
            # to identify the DC that should recieve the info.
            xt_logger->info($exception->message());
        } else {
            xt_logger->warn(sprintf('Error occurred attempting to consume Delivery-Event message: %s',
                $exception
            ));
        }

        $return = 0;
    };

    return $return;
}

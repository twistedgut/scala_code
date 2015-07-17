package Test::XT::DC::Messaging::Consumer::Shipment;
use NAP::policy qw/class test/;

use Test::XTracker::LoadTestConfig;
use XTracker::Constants qw/ :sos_delivery_event_type /;
use Test::MockModule;
use Test::MockObject::Builder;
use XT::DC::Messaging::Consumer::Shipment;
use NAP::XT::Exception::Delivery::Event::NoMatchingShipment;

BEGIN { extends 'NAP::Test::Class' };

sub test__delivery_event :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Valid parameters return ok',
            setup   => {
                # These parameters are irrelevant (except for 'event_happened_at') as the
                # constructor is mocked to do what we want to test, but included for
                # completeness
                parameters => {
                    waybill_number      => '123456',
                    order_number        => '654321',
                    sos_event_type      => $SOS_DELIVERY_EVENT_TYPE__ATTEMPTED,
                    event_happened_at   => '2014-10-08T15:04:20'
                },
            },
            result  => {
                return_value => 1,
            },
        },
        {
            name    => 'Exception results in return not ok',
            setup   => {
                # These parameters are irrelevant (except for 'event_happened_at') as the
                # constructor is mocked to do what we want to test, but included for
                # completeness
                parameters => {
                    waybill_number      => '123456',
                    order_number        => '654321',
                    sos_event_type      => $SOS_DELIVERY_EVENT_TYPE__ATTEMPTED,
                    event_happened_at   => '2014-10-08T15:04:20'
                },
                exception_to_throw => NAP::XT::Exception::Delivery::Event::NoMatchingShipment->new({
                    order_number    => '654321',
                    waybill_number  => '123456',
                }),
            },
            result  => {
                return_value => 0,
            },
        }
    ) {
        subtest $test->{name} => sub {
            my $mocked_delivery_event_module = $self->_create_mocked_delivery_event_module($test);

            my $return_value = XT::DC::Messaging::Consumer::Shipment->delivery_event(
                $test->{setup}->{parameters},
                {}
            );
            is($return_value, $test->{result}->{return_value}, 'Return value is as expected');
        };
    }
}

sub _create_mocked_delivery_event_module {
    my ($self, $test) = @_;

    my $mocked_module = Test::MockModule->new('XTracker::Delivery::Event');

    # If we don't want an error, throw back an object that will behave nicely :)
    $mocked_module->mock('new' => sub {

        $test->{setup}->{exception_to_throw}->throw()
            if $test->{setup}->{exception_to_throw};

        return Test::MockObject::Builder->build({
            mock => {
                log_in_database => 1,
            }
        });
    });

    return $mocked_module;
}

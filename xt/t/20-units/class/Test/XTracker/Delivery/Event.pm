package Test::XTracker::Delivery::Event;
use NAP::policy qw/class test/;
use Test::XTracker::Data;
use XTracker::Delivery::Event;
use XTracker::Constants::FromDB qw/ :shipment_status /;
use XTracker::Constants qw/ :sos_delivery_event_type /;
use Test::MockModule;

BEGIN { extends 'NAP::Test::Class' };

sub test__constructor :Tests {
    my ($self) = @_;


    # Note that with these tests, we can only create one shipment per order due to the
    # how XT's test libraries work :/
    for my $test (
        {
            name    => 'Valid constructor arguments, with valid db data constructs OK',
            setup   => {
                params  => {
                    order_number        => 'DeliveryEventTest42',
                    waybill_number      => 'Wibble12',
                    sos_event_type      => $SOS_DELIVERY_EVENT_TYPE__COMPLETED,
                    event_happened_at   => {
                        year    => '2014',
                        month   => '10',
                        day     => '7'
                    },
                },
                orders => [
                    {
                        order_number            => 'DeliveryEventTest41',
                        outward_airway_bill  => 'Wobble21',
                    },
                    {
                        order_number => 'DeliveryEventTest42',

                        # *This* shipment should be fetched by the Delivery::Event,
                        # as the order's order_number and the shipment's
                        # outward-waybill number match the test contructor-parameters
                        # defined above
                        outward_airway_bill => 'Wibble12',

                    }
                ]
            },
            result  => {
                # When we test the shipment that the Delivery::Event sends back, then it
                # should have this data (that matches our test contructor parameters)
                event_data => {
                    waybill_number          => 'Wibble12',
                    shipment_status_id      => $SHIPMENT_STATUS__DELIVERED,
                },
            },
        },
        {
            name    => 'No shipment or order_number parameter throws an exception',
            setup   => {
                params  => {
                    # Note that these parameters are the same as those in the 'valid'
                    # test, but missing the order_number
                    #order_number        => 'DeliveryEventTest42',
                    waybill_number      => 'Wibble12',
                    sos_event_type      => $SOS_DELIVERY_EVENT_TYPE__COMPLETED,
                    event_happened_at   => {
                        year    => '2014',
                        month   => '10',
                        day     => '7'
                    },
                },
                orders => [
                    {
                        order_number            => 'DeliveryEventTest41',
                        outward_airway_bill  => 'Wobble21',
                    },
                    {
                        order_number => 'DeliveryEventTest42',

                        # *This* shipment should be fetched by the Delivery::Event,
                        # as the order's order_number and the shipment's
                        # outward-waybill number match the test contructor-parameters
                        # defined above
                        outward_airway_bill => 'Wibble12',

                    }
                ]
            },
            result  => {
                error_isa => 'NAP::XT::Exception::MissingRequiredParameters',
            },
        },
        {
            name    => 'No shipment or waybill_number parameter throws an exception',
            setup   => {
                params  => {
                    # Note that these parameters are the same as those in the 'valid'
                    # test, but missing the waybill_number
                    order_number        => 'DeliveryEventTest42',
                    #waybill_number      => 'Wibble12',
                    sos_event_type      => $SOS_DELIVERY_EVENT_TYPE__COMPLETED,
                    event_happened_at   => {
                        year    => '2014',
                        month   => '10',
                        day     => '7'
                    },
                },
                orders => [
                    {
                        order_number            => 'DeliveryEventTest41',
                        outward_airway_bill  => 'Wobble21',
                    },
                    {
                        order_number => 'DeliveryEventTest42',

                        # *This* shipment should be fetched by the Delivery::Event,
                        # as the order's order_number and the shipment's
                        # outward-waybill number match the test contructor-parameters
                        # defined above
                        outward_airway_bill => 'Wibble12',

                    }
                ]
            },
            result  => {
                error_isa => 'NAP::XT::Exception::MissingRequiredParameters',
            },
        },
        {
            name    => 'No shipment or sos_event_type parameter throws an exception',
            setup   => {
                params  => {
                    # Note that these parameters are the same as those in the 'valid'
                    # test, but missing the sos_event_type
                    order_number        => 'DeliveryEventTest42',
                    waybill_number      => 'Wibble12',
                    #sos_event_type      => $SOS_DELIVERY_EVENT_TYPE__COMPLETED,
                    event_happened_at   => {
                        year    => '2014',
                        month   => '10',
                        day     => '7'
                    },
                },
                orders => [
                    {
                        order_number            => 'DeliveryEventTest41',
                        outward_airway_bill  => 'Wobble21',
                    },
                    {
                        order_number => 'DeliveryEventTest42',

                        # *This* shipment should be fetched by the Delivery::Event,
                        # as the order's order_number and the shipment's
                        # outward-waybill number match the test contructor-parameters
                        # defined above
                        outward_airway_bill => 'Wibble12',

                    }
                ]
            },
            result  => {
                error_isa => 'NAP::XT::Exception::MissingRequiredParameters',
            },
        },
        {
            name    => 'Invalid sos_event_type throws an exception',
            setup   => {
                params  => {
                    # Note that these parameters are the same as those in the 'valid'
                    # test, except that the sos_event_type is a nonsense
                    order_number        => 'DeliveryEventTest42',
                    waybill_number      => 'Wibble12',
                    sos_event_type      => 'wibble',
                    event_happened_at   => {
                        year    => '2014',
                        month   => '10',
                        day     => '7'
                    },
                },
                orders => [
                    {
                        order_number            => 'DeliveryEventTest41',
                        outward_airway_bill  => 'Wobble21',
                    },
                    {
                        order_number => 'DeliveryEventTest42',

                        # *This* shipment should be fetched by the Delivery::Event,
                        # as the order's order_number and the shipment's
                        # outward-waybill number match the test contructor-parameters
                        # defined above
                        outward_airway_bill => 'Wibble12',

                    }
                ]
            },
            result  => {
                error_isa => 'NAP::XT::Exception::Delivery::Event::UnknownEventType',
            },
        },
        {
            name    => 'When no shipment/order matches the waybill_number/order_number, throw an exception',
            setup   => {
                params  => {
                    # Note that these parameters are the same as those in the 'valid'
                    # test, except that the order_number does not match any of the
                    # test orders
                    order_number        => 'DeliveryEventTest666',
                    waybill_number      => 'Wibble21',
                    sos_event_type      => 'wibble',
                    event_happened_at   => {
                        year    => '2014',
                        month   => '10',
                        day     => '7'
                    },
                },
                orders => [
                    {
                        order_number            => 'DeliveryEventTest41',
                        outward_airway_bill  => 'Wobble21',
                    },
                    {
                        order_number => 'DeliveryEventTest42',

                        # *This* shipment should be fetched by the Delivery::Event,
                        # as the order's order_number and the shipment's
                        # outward-waybill number match the test contructor-parameters
                        # defined above
                        outward_airway_bill => 'Wibble12',

                    }
                ]
            },
            result  => {
                error_isa => 'NAP::XT::Exception::Delivery::Event::NoMatchingShipment',
            },
        }
    ) {
        my ($self) = @_;

        subtest $test->{name} => sub {

            my ($matching_shipment, $mocked_delivery_event_module) = $self->_create_constructor_test_data($test);

            my $event_happened_at = DateTime->new($test->{setup}->{params}->{event_happened_at});

            if ($test->{result}->{error_isa}) {
                throws_ok {
                    XTracker::Delivery::Event->new({
                        %{$test->{setup}->{params}},
                        event_happened_at => $event_happened_at
                    });
                } $test->{result}->{error_isa}, 'Expected error has been thrown';
                return;
            }


            my $delivery_event = XTracker::Delivery::Event->new({
                %{$test->{setup}->{params}},
                event_happened_at => $event_happened_at
            });

            eq_or_diff({
                waybill_number          => $delivery_event->shipment->outward_airway_bill(),
                shipment_status_id      => $delivery_event->shipment_status_id(),
            }, $test->{result}->{event_data}, 'Delivery event data is as expected');
        };
    }
}

sub _create_constructor_test_data {
    my ($self, $test) = @_;

    my $matching_shipment;
    my @shipment_ids;

    # Create the test order/shipment data
    for my $order_def (@{$test->{setup}->{orders}}) {

        my $order = $self->_create_order($order_def);

        my @order_shipment_ids = map { $_->id() } $order->shipments->all();

        @shipment_ids = [@shipment_ids, @order_shipment_ids];

        my $order_shipment = $order->shipments->first();

        $matching_shipment = $order_shipment
            if (
                defined($test->{setup}->{params}->{order_number})
                && $order->order_nr() eq $test->{setup}->{params}->{order_number}
                && defined($test->{setup}->{params}->{waybill_number})
                && $order_shipment->outward_airway_bill() eq $test->{setup}->{params}->{waybill_number}
            );
    }

    # Mock the resultset that the Delivery::Event uses to only contain our test shipments
    my $test_shipment_rs = $self->schema->resultset('Public::Shipment')->search({
        'me.id' => \@shipment_ids,
    });

    my $mocked_delivery_event_module = Test::MockModule->new('XTracker::Delivery::Event');
    $mocked_delivery_event_module->mock('_get_shipment_rs' => sub {
        return $test_shipment_rs;
    });

    return ($matching_shipment, $mocked_delivery_event_module);
}

sub _create_order {
    my ($self, $order_def) = @_;

    # See if this order is already there from a previous test run
    # (Note that this make sthe horrible assumption that nothing will have mucked
    # about with this data in the meantime :/ but it is very hard to get rid of order
    # data once it is there)
    my $order = $self->schema->resultset('Public::Orders')->find({
        order_nr => $order_def->{order_number}
    });

    if (!$order) {
        my ($channel, $pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
        });

        ($order, undef) = Test::XTracker::Data->create_db_order({
            pids                => $pids,
            channel             => $channel,
            base                => {
                order_nr            => $order_def->{order_number},
                outward_airway_bill => $order_def->{outward_airway_bill},
            },
        });
    }

    return $order;
}

sub test__log_in_database :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Create a status log using a valid delivery-event',
            setup   => {
                order => {
                    order_number            => 'DeliveryEventTest41',
                    outward_airway_bill     => 'Wobble21',
                },
                params => {
                    # Note that we will pass in the shipment object created with the test
                    # order data defined above
                    #shipment           => $test_shipment
                    shipment_status_id  => $SHIPMENT_STATUS__DELIVERED,
                    event_happened_at   => {
                        year    => '2014',
                        month   => '10',
                        day     => '7'
                    },
                },
            },
            result  => {
                status_log => {
                    shipment_status_id => $SHIPMENT_STATUS__DELIVERED
                }
            },
        }
    ) {
        subtest $test->{name} => sub {
            my $test_shipment = $self->_create_log_in_database_test_data($test);

            my $event_happened_at = DateTime->new($test->{setup}->{params}->{event_happened_at});

            my $delivery_event = XTracker::Delivery::Event->new({
                %{$test->{setup}->{params}},
                shipment            => $test_shipment,
                event_happened_at   => $event_happened_at
            });

            lives_ok { $delivery_event->log_in_database(); } 'Call to log_in_database lives';

            my $status_log = $test_shipment->shipment_status_logs->first();
            ok(defined($status_log), 'Status log has been created') || return;

            is($status_log->shipment_status_id(),
                $test->{result}->{status_log}->{shipment_status_id},
                'Shipment status log has been updated'
            );
        };
    }
}

sub _create_log_in_database_test_data {
    my ($self, $test) = @_;

    my $test_order = $self->_create_order($test->{setup}->{order});
    my $shipment = $test_order->shipments->first();

    # Remove any existing shipment_status logs for this shipment
    $shipment->shipment_status_logs->search_related('shipment_hold_logs')->delete();
    $shipment->shipment_status_logs->delete();

    return $shipment;
}

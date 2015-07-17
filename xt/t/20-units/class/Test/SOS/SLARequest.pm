package Test::SOS::SLARequest;
use NAP::policy "tt", 'class', 'test';

use Test::XTracker::LoadTestConfig;

use XTracker::Constants::FromDB qw(
    :sos_week_day
);

BEGIN {
    extends 'NAP::Test::Class';

    use Test::SOS::Data;
    has 'data_helper' => (
        is      => 'ro',
        lazy    => 1,
        default => sub { Test::SOS::Data->new() },
    );

};

use SOS::SLARequest;
use DateTime::Duration;

sub test__validate_params_and_create_shipment {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Valid (no region, not express, not slow)',
            setup   => {
                test_data => {
                    shipment_classes    => ['Cheap', 'Expensive'],
                    carriers            => ['Bill', 'Ben'],
                    countries           => [ 'Munchkinland', 'Milk n Honey' ],
                    regions             => { 'Munchkinland' => [ 'Emerald City' ]},
                    channels            => [ 'MnS', 'HoF' ],
                },
                request_params      => {
                    shipment_class_code     => 'Cheap',
                    carrier_code            => 'Bill',
                    country_code            => 'Munchkinland',
                    channel_code            => 'MnS',
                    selection_date_epoch    => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 20,
                        hour        => 16,
                        minute      => 29,
                        time_zone   => 'UTC'
                    )->epoch(),
                    is_express              => 0,
                    is_slow                 => 0,
                },
                system_time_zone    => 'America/New_York',
            },

            expected => {
                # These should all match entries in the test data and therefore validate
                shipment_class_code         => 'Cheap',
                carrier_code                => 'Bill',
                country_code                => 'Munchkinland',
                channel_code                => 'MnS',
                # No region because we didn't pass one
                region_code                 => undef,
                # The selection date should be the same one we passed but converted to
                # the system timezone
                selection_datetime_string   => DateTime->new(
                    year        => 2014,
                    month       => 3,
                    day         => 20,
                    hour        => 16,
                    minute      => 29,
                    time_zone   => 'UTC'
                )->set_time_zone('America/New_York') . '',
                is_express                  => 0,
                is_slow                     => 0,
            },
        },

        {
            name    => 'Valid (with nominated-day, region, express and slow)',
            setup => {
                test_data => {
                    shipment_classes    => ['Cheap', 'Expensive'],
                    carriers            => ['Bill', 'Ben'],
                    countries           => [ 'Munchkinland', 'Milk n Honey' ],
                    regions             => { 'Munchkinland' => [ 'Emerald City' ]},
                    channels            => [ 'MnS', 'HoF' ],
                },
                request_params      => {
                    shipment_class_code     => 'Cheap',
                    carrier_code            => 'Bill',
                    country_code            => 'Munchkinland',
                    region_code             => 'Emerald City',
                    channel_code            => 'MnS',
                    selection_date_epoch    => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 20,
                        hour        => 16,
                        minute      => 29,
                        time_zone   => 'UTC'
                    )->epoch(),
                    is_express              => 1,
                    is_slow                 => 1,
                },
                system_time_zone    => 'America/New_York',
            },

            expected => {
                # These should all match entries in the test data and therefore validate
                shipment_class_code         => 'Cheap',
                carrier_code                => 'Bill',
                country_code                => 'Munchkinland',
                channel_code                => 'MnS',
                region_code                 => 'Emerald City',
                # The selection date should be the same one we passed but converted to
                # the system timezone
                selection_datetime_string   => DateTime->new(
                    year        => 2014,
                    month       => 3,
                    day         => 20,
                    hour        => 16,
                    minute      => 29,
                    time_zone   => 'UTC'
                )->set_time_zone('America/New_York') . '',
                is_express                  => 1,
                is_slow                     => 1,
            },
        },

        {
            name        => 'Invalid (bad shipment class)',
            setup => {
                test_data => {
                    shipment_classes    => ['Cheap', 'Expensive'],
                    carriers            => ['Bill', 'Ben'],
                    countries           => [ 'Munchkinland', 'Milk n Honey' ],
                    regions             => { 'Munchkinland' => [ 'Emerald City' ]},
                    channels            => [ 'MnS', 'HoF' ],
                },
                request_params      => {
                    # This shipment code does not exist in our test data
                    shipment_class_code     => 'Free',
                    carrier_code            => 'Bill',
                    country_code            => 'Munchkinland',
                    region_code             => 'Emerald City',
                    channel_code            => 'MnS',
                    selection_date_epoch    => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 20,
                        hour        => 16,
                        minute      => 29,
                        time_zone   => 'UTC'
                    )->epoch(),
                    is_express              => 1,
                    is_slow                 => 1,
                },
                system_time_zone    => 'America/New_York',
            },
            expected    => {
                # This exception is thrown as the shipment-class does not exist
                error_isa => 'SOS::Exception::InvalidShipmentClassCode',
            },
        },


        {
            name        => 'Invalid (bad carrier)',
            setup => {
                test_data => {
                    shipment_classes    => ['Cheap', 'Expensive'],
                    carriers            => ['Bill', 'Ben'],
                    countries           => [ 'Munchkinland', 'Milk n Honey' ],
                    regions             => { 'Munchkinland' => [ 'Emerald City' ]},
                    channels            => [ 'MnS', 'HoF' ],
                },
                request_params      => {
                    shipment_class_code     => 'Cheap',
                    # This carrier code does not exist in our test data
                    carrier_code            => 'Pigeon',
                    country_code            => 'Munchkinland',
                    region_code             => 'Emerald City',
                    channel_code            => 'MnS',
                    selection_date_epoch    => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 20,
                        hour        => 16,
                        minute      => 29,
                        time_zone   => 'UTC'
                    )->epoch(),
                    is_express              => 1,
                    is_slow                 => 1,
                },
                system_time_zone    => 'America/New_York',
            },
            expected    => {
                # This exception is thrown as the carrier does not exist
                error_isa => 'SOS::Exception::InvalidCarrierCode',
            },
        },

        {
            name        => 'Invalid (bad channel)',
            setup => {
                test_data => {
                    shipment_classes    => ['Cheap', 'Expensive'],
                    carriers            => ['Bill', 'Ben'],
                    countries           => [ 'Munchkinland', 'Milk n Honey' ],
                    regions             => { 'Munchkinland' => [ 'Emerald City' ]},
                    channels            => [ 'MnS', 'HoF' ],
                },
                request_params      => {
                    shipment_class_code     => 'Cheap',
                    carrier_code            => 'Bill',
                    country_code            => 'Munchkinland',
                    region_code             => 'Emerald City',
                    # This channel code does not exist in our test data
                    channel_code            => 'Tesco',
                    selection_date_epoch    => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 20,
                        hour        => 16,
                        minute      => 29,
                        time_zone   => 'UTC'
                    )->epoch(),
                    is_express              => 1,
                    is_slow                 => 1,
                },
                system_time_zone    => 'America/New_York',
            },
            expected    => {
                # This exception is thrown as the channel does not exist
                error_isa => 'SOS::Exception::InvalidChannelCode',
            },
        },

        {
            name        => 'Invalid (bad country)',
            setup => {
                test_data => {
                    shipment_classes    => ['Cheap', 'Expensive'],
                    carriers            => ['Bill', 'Ben'],
                    countries           => [ 'Munchkinland', 'Milk n Honey' ],
                    regions             => { 'Munchkinland' => [ 'Emerald City' ]},
                    channels            => [ 'MnS', 'HoF' ],
                },
                request_params      => {
                    shipment_class_code     => 'Cheap',
                    carrier_code            => 'Bill',
                    # This country code does not exist in our test data
                    country_code            => 'Wonderland',
                    channel_code            => 'MnS',
                    selection_date_epoch    => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 20,
                        hour        => 16,
                        minute      => 29,
                        time_zone   => 'UTC'
                    )->epoch(),
                    is_express              => 1,
                    is_slow                 => 1,
                },
                system_time_zone    => 'America/New_York',
            },
            expected    => {
                # This exception is thrown as the country does not exist
                error_isa => 'SOS::Exception::InvalidCountryCode',
            },
        },

        {
            name        => 'Invalid (region that exists but for wrong country)',
            setup => {
                test_data => {
                    shipment_classes    => ['Cheap', 'Expensive'],
                    carriers            => ['Bill', 'Ben'],
                    countries           => [ 'Munchkinland', 'Milk n Honey' ],
                    regions             => { 'Munchkinland' => [ 'Emerald City' ]},
                    channels            => [ 'MnS', 'HoF' ],
                },
                request_params      => {
                    shipment_class_code     => 'Cheap',
                    carrier_code            => 'Bill',
                    country_code            => 'Milk n Honey',
                    # This region code exists, but not for the above country
                    region_code             => 'Emerald City',
                    channel_code            => 'MnS',
                    selection_date_epoch    => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 20,
                        hour        => 16,
                        minute      => 29,
                        time_zone   => 'UTC'
                    )->epoch(),
                    is_express              => 1,
                    is_slow                 => 1,
                },
                system_time_zone    => 'America/New_York',
            },
            expected    => {
                # This exception is thrown as the region does not exist in the given country
                error_isa => 'SOS::Exception::InvalidRegionCode',
            },
        }
    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest: %s', $test->{name}));

            my $sla_request = $self->_create_sla_request($test);

            if ($test->{expected}->{error_isa}) {
                throws_ok(sub {
                    $sla_request->_validate_params_and_create_shipment(
                        $test->{setup}->{request_params}
                    );
                }, $test->{expected}->{error_isa}, 'Expected error thrown');
                return;
            }

            my $shipment;
            lives_ok {
                $shipment =
                    $sla_request->_validate_params_and_create_shipment(
                        $test->{setup}->{request_params}
                    );
            } 'get_sla_data() lives';

            isa_ok($shipment, 'SOS::Shipment') or return;

            eq_or_diff({
                shipment_class_code         => $shipment->shipment_class->api_code(),
                carrier_code                => $shipment->carrier->code(),
                country_code                => $shipment->country->api_code(),
                channel_code                => $shipment->channel->api_code(),
                region_code                 => ( $shipment->region()
                    ? $shipment->region->api_code()
                    : undef
                ),
                selection_datetime_string   => $shipment->selection_datetime() . '',
                is_express                  => $shipment->is_express(),
                is_slow                     => $shipment->is_slow(),
            }, $test->{expected}, 'Shipment data is as expected');

        };
    }
}

sub test__get_sla_data :Tests {
    my ($self) = @_;

    for my $test (
            {
                name    => 'Valid run without bump data',
                setup => {
                    test_data => {
                        shipment_classes    => ['Cheap', 'Expensive'],
                        carriers            => ['Bill', 'Ben'],
                        countries           => [ 'Munchkinland', 'Milk n Honey' ],
                        regions             => { 'Munchkinland' => [ 'Emerald City' ]},
                        channels            => [ 'MnS', 'HoF' ],
                        processing_times    => {
                            shipment_classes => {
                                'Cheap' => '02:00:00',
                            },
                        },
                        wms_priorities      => {
                            shipment_classes => {
                                'Cheap' => {
                                    'wms_priority' => 20,
                                },
                            },
                        },
                        truck_departures    => {
                            'Bill'  => {
                                'Cheap' => {
                                    'Monday'    => [{ hours => '12' }],
                                    'Tuesday'   => [{ hours => '12' }],
                                    'Wednesday' => [{ hours => '12' }],
                                    'Thursday'  => [{ hours => '12' }],
                                    'Friday'    => [{ hours => '12' }], # Should hit this truck
                                    'Saturday'  => [{ hours => '12' }],
                                    'Sunday'    => [{ hours => '12' }],
                                },
                            }
                        },
                    },
                    request_params      => {
                        shipment_class_code     => 'Cheap',
                        carrier_code            => 'Bill',
                        country_code            => 'Munchkinland',
                        region_code             => 'Emerald City',
                        channel_code            => 'MnS',
                        selection_date_epoch    => DateTime->new(
                            year        => 2014,
                            month       => 3,
                            day         => 20, # Thursday
                            hour        => 16, # 12 in America/New_York
                            minute      => 29,
                            time_zone   => 'UTC'
                        )->epoch(),
                        is_express              => 0,
                        is_slow                 => 0,
                    },
                    system_time_zone    => 'America/New_York',
                },
                expected    => {
                    # This is expected to be the processing time (2 hours) after the
                    # selection-date
                    wms_deadline_epoch  => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 20, # Thursday
                        hour        => 14,
                        minute      => 29,
                        time_zone   => 'America/New_York'
                    )->epoch(),
                    # This is the first truck time the day after the wms_deadline (as
                    # there are no remaining trucks after that time on the same day)
                    sla_epoch           => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 21, # Friday
                        hour        => 12,
                        minute      => 00,
                        time_zone   => 'America/New_York'
                    )->epoch(),
                    # This value was picked up from the shipment-class' wms_priority
                    # (the only one that is relevant to the request parameters)
                    wms_initial_pick_priority => 20,
                },
            },

            {
                name    => 'Valid run in special country with bump data',
                setup => {
                    test_data => {
                        shipment_classes    => ['Cheap', 'Expensive'],
                        carriers            => ['Bill', 'Ben'],
                        countries           => [ 'Munchkinland', 'Milk n Honey' ],
                        regions             => { 'Munchkinland' => [ 'Emerald City' ]},
                        channels            => [ 'MnS', 'HoF' ],
                        processing_times    => {
                            shipment_classes => {
                                'Cheap' => '02:00:00',
                            },
                        },
                        wms_priorities      => {
                            shipment_classes => {
                                'Cheap' => {
                                    'wms_priority' => 20,
                                },
                            },
                            countries => {
                                'Munchkinland' => {
                                    'wms_priority'          => 20,
                                    'wms_bumped_priority'   => 5,
                                    'bumped_interval'       => '01:30:00',
                                },
                            },
                        },
                        truck_departures    => {
                            'Bill'  => {
                                'Cheap' => {
                                    'Monday'    => [{ hours => '12' }],
                                    'Tuesday'   => [{ hours => '12' }],
                                    'Wednesday' => [{ hours => '12' }],
                                    'Thursday'  => [{ hours => '12' }],
                                    'Friday'    => [{ hours => '12' }], # Should hit this truck
                                    'Saturday'  => [{ hours => '12' }],
                                    'Sunday'    => [{ hours => '12' }],
                                },
                            }
                        },
                    },
                    request_params      => {
                        shipment_class_code     => 'Cheap',
                        carrier_code            => 'Bill',
                        country_code            => 'Munchkinland',
                        region_code             => 'Emerald City',
                        channel_code            => 'MnS',
                        selection_date_epoch    => DateTime->new(
                            year        => 2014,
                            month       => 3,
                            day         => 20, # Thursday
                            hour        => 16, # 12 in America/New_York
                            minute      => 29,
                            time_zone   => 'UTC'
                        )->epoch(),
                        is_express              => 0,
                        is_slow                 => 0,
                    },
                    system_time_zone    => 'America/New_York',
                },
                expected    => {
                    sla_epoch           => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 21, # Friday
                        hour        => 12,
                        minute      => 00,
                        time_zone   => 'America/New_York'
                    )->epoch(),
                    wms_deadline_epoch  => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 20, # Thursday
                        hour        => 14,
                        minute      => 29,
                        time_zone   => 'America/New_York'
                    )->epoch(),
                    wms_initial_pick_priority   => 20,
                    wms_bump_pick_priority      => 5,
                    wms_bump_deadline_epoch     => DateTime->new(
                        year        => 2014,
                        month       => 3,
                        day         => 21, # Friday
                        hour        => 10,
                        minute      => 30,
                        time_zone   => 'America/New_York'
                    )->epoch(),
                },
            },

            {
                name    => 'Invalid run (no trucks for that carrier)',
                setup => {
                    test_data => {
                        shipment_classes    => ['Cheap', 'Expensive'],
                        carriers            => ['Bill', 'Ben'],
                        countries           => [ 'Munchkinland', 'Milk n Honey' ],
                        regions             => { 'Munchkinland' => [ 'Emerald City' ]},
                        channels            => [ 'MnS', 'HoF' ],
                        processing_times    => {
                            shipment_classes => {
                                'Cheap' => '02:00:00',
                            },
                        },
                        wms_priorities      => {
                            shipment_classes => {
                                'Cheap' => {
                                    'wms_priority' => 20,
                                },
                            },
                        },
                        truck_departures    => {
                            # These trucks are NOT for the carrier that will be requested
                            'Ben'  => {
                                'Cheap' => {
                                    'Monday'    => [{ hours => '12' }],
                                    'Tuesday'   => [{ hours => '12' }],
                                    'Wednesday' => [{ hours => '12' }],
                                    'Thursday'  => [{ hours => '12' }],
                                    'Friday'    => [{ hours => '12' }],
                                    'Saturday'  => [{ hours => '12' }],
                                    'Sunday'    => [{ hours => '12' }],
                                },
                            }
                        },
                    },
                    request_params      => {
                        shipment_class_code     => 'Cheap',
                        # There are no truck departures for this carrier
                        carrier_code            => 'Bill',
                        country_code            => 'Munchkinland',
                        region_code             => 'Emerald City',
                        channel_code            => 'MnS',
                        selection_date_epoch    => DateTime->new(
                            year        => 2014,
                            month       => 3,
                            day         => 20, # Thursday
                            hour        => 16, # 12 in America/New_York
                            minute      => 29,
                            time_zone   => 'UTC'
                        )->epoch(),
                        is_express              => 0,
                        is_slow                 => 0,
                    },
                    system_time_zone    => 'America/New_York',
                },
                expected    => {
                    error => 'No truck departure could be found',
                },
            },

        ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest: %s', $test->{name}));

            my $sla_request = $self->_create_sla_request($test);

            my $return;
            lives_ok {
                $return = $sla_request->get_sla_data($test->{setup}->{request_params});
            } 'get_sla_data() lives';

            eq_or_diff($return, $test->{expected}, 'Return values as expected');

        };
    }
}

sub _create_sla_request {
    my ($self, $test) = @_;

    my $shipment_class_codes = $test->{setup}->{test_data}->{shipment_classes} // [];
    my @shipment_class_ids = map {
        $self->data_helper->find_or_create_shipment_class({ name => $_ })->id()
    } @$shipment_class_codes;
    my $shipment_class_rs = $self->schema->resultset('SOS::ShipmentClass')->search({
        'me.id' => \@shipment_class_ids,
    });

    my $carrier_codes = $test->{setup}->{test_data}->{carriers} // [];
    my @carrier_ids = map {
        $self->data_helper->find_or_create_carrier({ name => $_ })->id()
    } @$carrier_codes;
    my $carrier_rs = $self->schema->resultset('SOS::Carrier')->search({
        'me.id' => \@carrier_ids,
    });

    my $country_codes = $test->{setup}->{test_data}->{countries} // [];
    my @countrie_ids = map {
        $self->data_helper->find_or_create_country({ name => $_ })->id()
    } @$country_codes;
    my $country_rs = $self->schema->resultset('SOS::Country')->search({
        'me.id' => \@countrie_ids,
    });

    my @region_ids;
    my $region_hash = $test->{setup}->{test_data}->{regions} // {};
    for my $country_code (keys %$region_hash) {
        my $country = $self->data_helper->find_or_create_country({ name => $country_code });
        for my $region_code (@{$region_hash->{$country_code}}) {
            push @region_ids, $self->data_helper->find_or_create_region({
                name    => $region_code,
                country => $country,
            })->id();
        }
    }
    my $region_rs = $self->schema->resultset('SOS::Region')->search({
        'me.id' => \@region_ids,
    });

    my $channel_codes = $test->{setup}->{test_data}->{channels} // [];
    my @channel_ids = map {
        $self->data_helper->find_or_create_channel({ name => $_ })->id()
    } @$channel_codes;
    my $channel_rs = $self->schema->resultset('SOS::Channel')->search({
        'me.id' => \@channel_ids,
    });


    my @processing_time_ids;
    my $pt_hash = $test->{setup}->{test_data}->{processing_times} // {};
    for my $shipment_class_code (keys %{ $pt_hash->{shipment_classes} }) {
        push @processing_time_ids, $self->data_helper->find_or_update_processing_time({
            class           => $shipment_class_code,
            processing_time => $pt_hash->{shipment_classes}->{$shipment_class_code},
        })->id();
    }

    for my $attribute ( keys %{ $pt_hash->{shipment_class_attributes} } ) {
        push @processing_time_ids, $self->data_helper->find_or_update_processing_time({
           attribute       => $attribute,
           processing_time => $pt_hash->{shipment_class_attributes}{$attribute},
        })->id;
    }

    my $processing_times_rs = $self->schema->resultset('SOS::ProcessingTime')->search({
        'me.id' => \@processing_time_ids,
    });

    my @wms_priority_ids;
    my $priority_hash = $test->{setup}->{test_data}->{wms_priorities} // {};
    for my $shipment_class_code (keys %{ $priority_hash->{shipment_classes} }) {
        my $priority_values = $priority_hash->{shipment_classes}->{$shipment_class_code};
        push @wms_priority_ids, $self->data_helper->find_or_update_wms_priority({
            class           => $shipment_class_code,
            wms_priority => $priority_values->{wms_priority},
            ( $priority_values->{wms_bumped_priority}
                ? ( wms_bumped_priority => $priority_values->{wms_bumped_priority} )
                : ()
            ),
            ( $priority_values->{bumped_interval}
                ? ( bumped_interval => $priority_values->{bumped_interval} )
                : ()
            ),
        })->id();
    }
    for my $country_code (keys %{ $priority_hash->{countries} }) {
        my $priority_values = $priority_hash->{countries}->{$country_code};
        push @wms_priority_ids, $self->data_helper->find_or_update_wms_priority({
            country         => $country_code,
            wms_priority    => $priority_values->{wms_priority},
            ( $priority_values->{wms_bumped_priority}
                ? ( wms_bumped_priority => $priority_values->{wms_bumped_priority} )
                : ()
            ),
            ( $priority_values->{bumped_interval}
                ? ( bumped_interval => $priority_values->{bumped_interval} )
                : ()
            ),
        })->id();
    }
    my $wms_priority_rs = $self->schema->resultset('SOS::WmsPriority')->search({
        'me.id' => \@wms_priority_ids,
    });

    my @truck_departure_ids;
    my $td_hash = $test->{setup}->{test_data}->{truck_departures} // {};
    for my $carrier_code (keys %$td_hash) {
        for my $class_code (keys %{ $td_hash->{$carrier_code} }) {
            for my $week_day (keys %{ $td_hash->{$carrier_code}->{$class_code} }) {
                for my $truck_time (@{ $td_hash->{$carrier_code}->{$class_code}->{$week_day} }) {
                    push @truck_departure_ids, $self->data_helper->create_truck_departure({
                        carrier         => $carrier_code,
                        departure_time  => $truck_time,
                        shipment_classes=> [$class_code],
                        week_day        => $week_day,
                    })->id();
                }
            }
        }
    }
    my $truck_departure_rs = $self->schema->resultset('SOS::TruckDeparture')->search({
        'me.id' => \@truck_departure_ids,
    });

    return SOS::SLARequest->new({
        shipment_class_rs   => $shipment_class_rs,
        carrier_rs          => $carrier_rs,
        country_rs          => $country_rs,
        channel_rs          => $channel_rs,
        region_rs           => $region_rs,
        processing_times_rs => $processing_times_rs,
        wms_priority_rs     => $wms_priority_rs,
        truck_departure_rs  => $truck_departure_rs,
        system_time_zone    => $test->{setup}->{system_time_zone},
    });
}

package Test::XTracker::Role::SOS::Shippable;
use NAP::policy "tt", 'class', 'test';

BEGIN {

    use XTracker::Constants qw/
        :sos_shipment_class
        :sos_carrier
        :sos_channel
    /;
    use XTracker::Constants::FromDB qw/
        :carrier
    /;

    extends 'NAP::Test::Class';

    has 'requested_datetime' => ( is => 'ro', default => sub {
        DateTime->new(
            year        => 2013,
            month       => 11,
            day         => 14,
            hour        => 16,
            minute      => 19,
            time_zone   => 'Europe/London'
        );
    } );

    has 'requested_datetime_no_time_zone' => ( is => 'ro', default => sub {
        DateTime->new(
            year        => 2013,
            month       => 11,
            day         => 14,
            hour        => 16,
            minute      => 19,
        );
    } );

    has 'sla_datetime' => ( is => 'ro', default => sub {
        DateTime->new(
            year        => 2013,
            month       => 12,
            day         => 1,
            hour        => 9,
            minute      => 15,
            time_zone   => 'Europe/London'
        );
    } );

    has 'wms_initial_pick_priority' => ( is => 'ro', default     => 5 );

    has 'wms_deadline_datetime' => ( is => 'ro', default => sub {
        DateTime->new(
            year        => 2013,
            month       => 11,
            day         => 30,
            hour        => 7,
            minute      => 14,
            time_zone   => 'Europe/London'
        );
    } );

    has 'wms_bump_pick_priority' => ( is => 'ro', default     => 2 );

    has 'wms_bump_deadline_datetime' => ( is => 'ro', default => sub {
        DateTime->new(
            year        => 2013,
            month       => 11,
            day         => 29,
            hour        => 6,
            minute      => 13,
            time_zone   => 'Europe/London'
        );
    } );

    has 'country_code' => ( is => 'ro', default=> 'UK' );
    has 'region_code' => ( is => 'ro', default=> 'Hampshire' );
    has 'shipment_class_code' => ( is => 'ro', default=> $SOS_SHIPMENT_CLASS__STANDARD );
    has 'carrier_code' => ( is => 'ro', default => $SOS_CARRIER__UPS );
    has 'carrier' => ( is => 'ro', default => sub {
        my ($self) = @_;
        return $self->schema->resultset('SOS::Carrier')->find({
            code => $self->carrier_code(),
        });
    } );
    has 'channel_code' => ( is => 'ro', default => $SOS_CHANNEL__NAP );
};

use Test::XTracker::Role::SOS::Shippable::TestShippable;
use Test::MockObject::Builder;
use DateTime;
use Storable 'dclone';


sub test__get_shippable_shipment_class_code :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Standard shippable',
            shippable_settings  => {
                shippable_is_transfer       => 0,
                shippable_is_rtv            => 0,
                shippable_is_staff          => 0,
                shippable_is_premier_daytime=> 0,
                shippable_is_premier_evening=> 0,
                shippable_is_premier_all_day=> 0,
                shippable_is_virtual_only   => 0,
                shippable_is_nominated_day  => 0,
            },
            expected => {
                class_code  => $SOS_SHIPMENT_CLASS__STANDARD,
            },
        },

        {
            name    => 'Transfer shippable',
            shippable_settings  => {
                shippable_is_transfer       => 1,
                shippable_is_rtv            => 0,
                shippable_is_staff          => 0,
                shippable_is_premier_daytime=> 0,
                shippable_is_premier_evening=> 0,
                shippable_is_premier_all_day=> 0,
                shippable_is_virtual_only   => 0,
                shippable_is_nominated_day  => 0,
            },
            expected => {
                class_code  => $SOS_SHIPMENT_CLASS__TRANSFER,
            },
        },

        {
            name    => 'Return shippable',
            shippable_settings  => {
                shippable_is_transfer       => 0,
                shippable_is_rtv            => 1,
                shippable_is_staff          => 0,
                shippable_is_premier_daytime=> 0,
                shippable_is_premier_evening=> 0,
                shippable_is_premier_all_day=> 0,
                shippable_is_virtual_only   => 0,
                shippable_is_nominated_day  => 0,
            },
            expected => {
                class_code  => $SOS_SHIPMENT_CLASS__TRANSFER,
            },
        },

        {
            name    => 'Staff shippable',
            shippable_settings  => {
                shippable_is_transfer       => 0,
                shippable_is_rtv            => 0,
                shippable_is_staff          => 1,
                shippable_is_premier_daytime=> 0,
                shippable_is_premier_evening=> 0,
                shippable_is_premier_all_day=> 0,
                shippable_is_virtual_only   => 0,
                shippable_is_nominated_day  => 0,
            },
            expected => {
                class_code  => $SOS_SHIPMENT_CLASS__STAFF,
            },
        },

        {
            name    => 'Premier Daytime shippable',
            shippable_settings  => {
                shippable_is_transfer       => 0,
                shippable_is_rtv            => 0,
                shippable_is_staff          => 0,
                shippable_is_premier_daytime=> 1,
                shippable_is_premier_evening=> 0,
                shippable_is_premier_all_day=> 0,
                shippable_is_virtual_only   => 0,
                shippable_is_nominated_day  => 0,
            },
            expected => {
                class_code  => $SOS_SHIPMENT_CLASS__PREMIER_DAYTIME,
            },
        },

        {
            name    => 'Premier Evening shippable',
            shippable_settings  => {
                shippable_is_transfer       => 0,
                shippable_is_rtv            => 0,
                shippable_is_staff          => 0,
                shippable_is_premier_daytime=> 0,
                shippable_is_premier_evening=> 1,
                shippable_is_premier_all_day=> 0,
                shippable_is_virtual_only   => 0,
            },
            expected => {
                class_code  => $SOS_SHIPMENT_CLASS__PREMIER_EVENING,
            },
        },

        {
            name    => 'Premier All DAy shippable',
            shippable_settings  => {
                shippable_is_transfer       => 0,
                shippable_is_rtv            => 0,
                shippable_is_staff          => 0,
                shippable_is_premier_daytime=> 0,
                shippable_is_premier_evening=> 0,
                shippable_is_premier_all_day=> 1,
                shippable_is_virtual_only   => 0,
            },
            expected => {
                class_code  => $SOS_SHIPMENT_CLASS__PREMIER_ALL_DAY,
            },
        },

        {
            name    => 'Email shippable',
            shippable_settings  => {
                shippable_is_transfer       => 0,
                shippable_is_rtv            => 0,
                shippable_is_staff          => 0,
                shippable_is_premier_daytime=> 0,
                shippable_is_premier_evening=> 0,
                shippable_is_premier_all_day=> 0,
                shippable_is_virtual_only   => 1,
                shippable_is_nominated_day  => 0,
            },
            expected => {
                class_code  => $SOS_SHIPMENT_CLASS__EMAIL,
            },
        },

        {
            name    => 'Nominated Day shippable',
            shippable_settings  => {
                shippable_is_transfer       => 0,
                shippable_is_rtv            => 0,
                shippable_is_staff          => 0,
                shippable_is_premier_daytime=> 0,
                shippable_is_premier_evening=> 0,
                shippable_is_premier_all_day=> 0,
                shippable_is_virtual_only   => 0,
                shippable_is_nominated_day  => 1,
            },
            expected => {
                class_code  => $SOS_SHIPMENT_CLASS__NOMDAY,
            },
        },
    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest: %s', $test->{name}));

            my $test_shippable = Test::XTracker::Role::SOS::Shippable::TestShippable->new(
                $test->{shippable_settings}
            );
            is($test_shippable->_get_shippable_shipment_class_code(),
                $test->{expected}->{class_code}, 'shipment class code as expected');
        };
    }
}

sub test__get_shippable_carrier_code :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Valid carrier',
            setup  => {
                carrier_id      => $CARRIER__UNKNOWN,
                carrier_name    => 'Net-A-Porter',
            },
            expected => {
                carrier_code  => $SOS_CARRIER__NAP,
            },
        },

        {
            name    => 'Invalid carrier',
            setup  => {
                carrier_id      => 'wibble',
                carrier_name    => 'Wibble Delivery Service',
            },
            expected => {
                error_isa => 'NAP::XT::Exception::SOS::UnmappableCarrier',
            },
        },

    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest: %s', $test->{name}));

            my $mock_carrier = Test::MockObject->new();
            $mock_carrier->set_isa('XTracker::Schema::Result::Public::Carrier');
            $mock_carrier->mock('id', sub { $test->{setup}->{carrier_id} });
            $mock_carrier->mock('name', sub { $test->{setup}->{carrier_name} });

            my $test_shippable = Test::XTracker::Role::SOS::Shippable::TestShippable->new(
                get_shippable_carrier => $mock_carrier
            );

            if ($test->{expected}->{error_isa}) {
                throws_ok(sub {
                    $test_shippable->_get_shippable_carrier_code()
                }, $test->{expected}->{error_isa},
                    '_get_shippable_carrier_code() throws expected exception');
                return;
            }

            is($test_shippable->_get_shippable_carrier_code(),
                $test->{expected}->{carrier_code}, 'carrier code as expected');
        };
    }
}

sub test__get_sla_data :Tests {
    my ($self) = @_;

    # These 'bases' represent standard test values that are valid for most of the
    # below tests
    my $base_shippable_data = {
        overrided_carrier_code                  => $self->carrier_code(),
        overrided_shippable_class_code          => $self->shipment_class_code(),
        overrided_channel_code                  => $self->channel_code(),
        get_shippable_requested_datetime        => $self->requested_datetime(),
        get_shippable_country_code              => $self->country_code(),
        get_shippable_region_code               => $self->region_code(),
        is_sos_enabled                          => 1,
        shippable_is_express                    => 0,
        shippable_is_eip                        => 0,
        shippable_is_slow                       => 0,
        shippable_is_mixed_sale                 => 0,
        shippable_is_full_sale                  => 0,
    };

    my $base_setup_return_values = {
        sla_epoch                   => $self->sla_datetime->epoch(),
        wms_initial_pick_priority   => $self->wms_initial_pick_priority(),
        wms_deadline_epoch          => $self->wms_deadline_datetime->epoch(),
    };

    my $base_params_passed = {
        shipment_class_code     => $self->shipment_class_code(),
        carrier_code            => $self->carrier_code(),
        country_code            => $self->country_code(),
        channel_code            => $self->channel_code(),
        region_code             => $self->region_code(),
        selection_date_epoch    => $self->requested_datetime->epoch(),
        is_express              => 0,
        is_eip                  => 0,
        is_slow                 => 0,
        is_mixed_sale           => 0,
        is_full_sale            => 0,
    };

    my $base_expected_return_values = {
        sla_cutoff_datetime     => $self->sla_datetime->set_time_zone('UTC') . '',
        wms_deadline_datetime   => $self->wms_deadline_datetime->set_time_zone('UTC') . '',
    };

    for my $test (
        {
            name    => 'Without bumped data',
            setup => {
                shippable_data  => $base_shippable_data,
                return_values   => $base_setup_return_values,
            },
            expected => {
                params_passed => $base_params_passed,
                return_values => $base_expected_return_values,
            },
        },

        {
            name    => 'With bumped data',
            setup => {
                shippable_data  => $base_shippable_data,
                return_values   => {
                    %{dclone($base_setup_return_values)},
                    wms_bump_pick_priority     => $self->wms_bump_pick_priority(),
                    wms_bump_deadline_epoch    => $self->wms_bump_deadline_datetime->epoch(),
                },
            },
            expected => {
                params_passed => $base_params_passed,
                return_values => {
                    %{dclone($base_expected_return_values)},
                    wms_bump_deadline_datetime => $self->wms_bump_deadline_datetime() . '',
                },
            },
        },


        {
            name    => 'No time-zone',
            setup => {
                shippable_data  => {
                    %{dclone($base_shippable_data)},
                    get_shippable_requested_datetime => $self->requested_datetime_no_time_zone()
                },
                return_values => $base_setup_return_values,
            },
            expected => {
                error_isa   => 'NAP::XT::Exception::SOS::NoTimeZone',
            },
        },

        {
            name    => 'SOS disabled',
            setup => {
                shippable_data  => {
                    %{dclone($base_shippable_data)},
                    is_sos_enabled => 0,
                },
                return_values => $base_setup_return_values,
            },
            expected => {
                error_isa => 'NAP::XT::Exception::SOS::IncompatibleShippable',
            },
        },

        {
            name    => 'Express shipment',
            setup => {
                shippable_data  => {
                    %{dclone($base_shippable_data)},
                    shippable_is_express => 1,
                },
                return_values   => $base_setup_return_values,
            },
            expected => {
                params_passed  => {
                    %{dclone($base_params_passed)},
                    is_express => 1,
                },
                return_values => $base_expected_return_values,
            },
        },

        {
            name    => 'EIP shipment',
            setup => {
                shippable_data  => {
                    %{dclone($base_shippable_data)},
                    shippable_is_eip => 1,
                },
                return_values   => $base_setup_return_values,
            },
            expected => {
                params_passed  => {
                    %{dclone($base_params_passed)},
                    is_eip => 1,
                },
                return_values => $base_expected_return_values,
            },
        },

        {
            name    => 'Slow shipment',
            setup => {
                shippable_data  => {
                    %{dclone($base_shippable_data)},
                    shippable_is_slow => 1,
                },
                return_values   => $base_setup_return_values,
            },
            expected => {
                params_passed  => {
                    %{dclone($base_params_passed)},
                    is_slow => 1,
                },
                return_values => $base_expected_return_values,
            },
        },
    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest: %s', $test->{name}));

            my $shipping_option_data_params;

            my $mock_sla_request = Test::MockObject::Builder->build({
                set_isa => 'SOS::SLARequest',
                mock    => {
                    'get_sla_data'  => sub {
                        # Store the parameters passed so we can test em later
                        (my $self, $shipping_option_data_params) = @_;
                        return $test->{setup}->{return_values};
                    },
                },
            });

            my $test_shippable = Test::XTracker::Role::SOS::Shippable::TestShippable->new(
                %{$test->{setup}->{shippable_data}},
                shipping_option_service => $mock_sla_request,
            );

            # Test for expected exception
            if ($test->{expected}->{error_isa}) {
                throws_ok(sub {
                    $test_shippable->get_sla_data();
                }, $test->{expected}->{error_isa}, 'Expected exception thrown');
                return;
            }

            # Test for success
            my (
                $sla_cutoff_datetime,
                $wms_initial_pick_priority,
                $wms_deadline_datetime,
                $wms_bump_pick_priority,
                $wms_bump_deadline_datetime
            );
            lives_ok {
                (
                    $sla_cutoff_datetime,
                    $wms_initial_pick_priority,
                    $wms_deadline_datetime,
                    $wms_bump_pick_priority,
                    $wms_bump_deadline_datetime
                ) = $test_shippable->get_sla_data();
            } 'get_sla_for_shippable() lives';

            eq_or_diff($shipping_option_data_params, $test->{expected}->{params_passed},
                'Params passed to SOS are as expected');

            my $wms_bump_deadline_datetime_hash = {};
            if ($wms_bump_deadline_datetime) {
                $wms_bump_deadline_datetime_hash = {
                    wms_bump_deadline_datetime => "$wms_bump_deadline_datetime",
                };
            }

            eq_or_diff({
                sla_cutoff_datetime     => "$sla_cutoff_datetime",
                wms_deadline_datetime   => "$wms_deadline_datetime",
                %$wms_bump_deadline_datetime_hash,
            }, $test->{expected}->{return_values}, 'Return datetimes are as expected');
        };
    }
}


sub test__get_emergency_sla_data :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'emergency SLA data is returned',
            setup   => {
                emergency_sla_interval_in_minutes   => 120,
                emergency_sla_initial_pick_priority => 20,
                now => { year => 2014, month => 4, day => 14, hour => 15 },
            },
            expected=> {
                emergency_sla_data => {
                    # The sla_cutoff should be 'now' + emergency_sla_interval_in_minutes
                    sla_cutoff => { year => 2014, month => 4, day => 14, hour => 17 },
                    # This should match the emergency_sla_initial_pick_priority
                    wms_initial_pick_priority   => 20,
                    # This should match 'now'
                    wms_deadline_datetime   => { year => 2014, month => 4, day => 14, hour => 15 },
                    # The 'bump' settings are currently always unset
                    wms_bump_pick_priority      => undef,
                    wms_bump_deadline_datetime  => undef,
                }
            }
        }
    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest %s', $test->{name}));

            my $mock_shippable = Test::MockObject::Builder->extend(
                Test::XTracker::Role::SOS::Shippable::TestShippable->new({
                    emergency_sla_interval_in_minutes => $test->{setup}->{emergency_sla_interval_in_minutes},
                    emergency_sla_initial_pick_priority => $test->{setup}->{emergency_sla_initial_pick_priority},
                }), {
                    validation_class=> 'Test::XTracker::Role::SOS::Shippable::TestShippable',
                    mock            => {
                        _get_now => sub { DateTime->new( %{$test->{setup}->{now}} )},
                    },
                }
            );

            my @emergency_sla_data = $mock_shippable->get_emergency_sla_data();
            is_deeply(\@emergency_sla_data, [
                DateTime->new( %{$test->{expected}->{emergency_sla_data}->{sla_cutoff}} ),
                $test->{expected}->{emergency_sla_data}->{wms_initial_pick_priority},
                DateTime->new( %{$test->{expected}->{emergency_sla_data}->{wms_deadline_datetime}} ),
                $test->{expected}->{emergency_sla_data}->{wms_bump_pick_priority},
                $test->{expected}->{emergency_sla_data}->{wms_bump_deadline_datetime},
            ], 'Returned emergency SLA data is as expected');
        };
    }
}

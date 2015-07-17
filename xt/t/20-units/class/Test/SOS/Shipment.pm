package Test::SOS::Shipment;
use NAP::policy "tt", 'class', 'test';
use Test::XTracker::LoadTestConfig;

BEGIN {
    extends 'NAP::Test::Class';

    use Test::SOS::Data;
    has 'sos_data_helper' => (
        is => 'ro',
        lazy => 1,
        default => sub { Test::SOS::Data->new() },
    );
};

use XTracker::Constants::FromDB qw/
    :sos_shipment_class
    :sos_shipment_class_attribute
/;
use DateTime;
use DateTime::Duration;
use Test::MockModule;
use Test::MockObject::Builder;

sub _wms_deadline { return DateTime->new(
    year    => 2013,
    month   => 12,
    day     => 9,
    hour    => 13,
    minute  => 35,
); }

sub _bump_interval { return DateTime::Duration->new(
    hours   => 1,
    minutes => 5
); }

sub _bump_priority { return 5 }

sub _truck_departure_datetime { return DateTime->new(
    year    => 2012,
    month   => 11,
    day     => 8,
    hour    => 11,
    minute  => 29,
); }

sub _bump_deadline_datetime { return DateTime->new(
    year    => 2012,
    month   => 11,
    day     => 8,
    hour    => 10,
    minute  => 24,
); }


sub test__wms_bump_deadline :Tests {
    my ($self) = @_;

    for my $test (
        {
            name => 'Got both bumped-priority and bumped-interval. '
                . 'Should return a bump-deadline',
            setup => {
                shipment => {
                    mock => {
                        wms_priority    => {
                            set_isa => 'XTracker::Schema::Result::SOS::WmsPriority',
                            mock    => {
                                bumped_interval     => $self->_bump_interval(),
                                wms_bumped_priority => $self->_bump_priority(),use_truck_departure_times_for_sla   => 1,
                            },
                        },
                        truck_departure_datetime            => $self->_truck_departure_datetime(),
                        use_truck_departure_times_for_sla   => 1,
                    },
                },
            },
            expected => {
                deadline_datetime => $self->_bump_deadline_datetime(),
            },
        },

        {
            name => 'Got bumped-priority but no bumped-interval. Should return undef',
            setup => {
                shipment => {
                    mock => {
                        wms_priority    => {
                            set_isa => 'XTracker::Schema::Result::SOS::WmsPriority',
                            mock    => {
                                bumped_interval     => undef,
                                wms_bumped_priority => $self->_bump_priority(),
                            },
                        },
                        wms_deadline                        => $self->_wms_deadline(),
                        use_truck_departure_times_for_sla   => 1,
                    },
                },
            },
            expected => {
                deadline_datetime => undef,
            },
        },

        {
            name => 'Got bumped-interval but no bumped-priority. Should return undef',
            setup => {
                shipment => {
                    mock => {
                        wms_priority    => {
                            set_isa => 'XTracker::Schema::Result::SOS::WmsPriority',
                            mock    => {
                                bumped_interval     => $self->_bump_interval(),
                                wms_bumped_priority => undef,
                            },
                        },
                        wms_deadline                        => $self->_wms_deadline(),
                        use_truck_departure_times_for_sla   => 1,
                    },
                },
            },
            expected => {
                deadline_datetime => undef,
            },
        },
    ) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest: %s', $test->{name}));

            my $shipment = Test::MockObject::Builder->extend(
                $self->sos_data_helper->create_shipment(),
                $test->{setup}->{shipment}
            );

            my $wms_deadline_datetime;

            lives_ok {
                $wms_deadline_datetime = $shipment->wms_bump_deadline();
            } 'wms_bump_deadline() lives';

            eq_or_diff($wms_deadline_datetime, $test->{expected}->{deadline_datetime},
                'Returned datetime has expected values');
        };
    }
}

sub _processing_time_interval { return DateTime::Duration->new(
    hours   => 2,
    minutes => 15
); }

sub _selection_datetime { return DateTime->new(
    year    => 2013,
    month   => 12,
    day     => 9,
    hour    => 11,
    minute  => 20,
); }

sub _selection_datetime_plus_processing_time { return DateTime->new(
    year    => 2013,
    month   => 12,
    day     => 9,
    hour    => 13,
    minute  => 35,
);}

sub test__get_sla_datetime :Tests {
    my ($self) = @_;

    my $data_helper = Test::SOS::Data->new();

    for my $test ({
        name    => 'SLA via truck departure',
        setup   => {
            shipment => {
                mock => {
                    use_truck_departure_times_for_sla   => 1,
                    truck_departure_datetime            => $self->_truck_departure_datetime(),
                    processing_time_interval            => $self->_processing_time_interval(),
                    selection_datetime                  => $self->_selection_datetime(),
                },
            }
        },
        result  => {
            sla_datetime => $self->_truck_departure_datetime()
        },
    },{
        name    => 'SLA not via truck departure',
        setup   => {
            shipment => {
                mock => {
                    use_truck_departure_times_for_sla   => 0,
                    truck_departure_datetime            => $self->_truck_departure_datetime(),
                    processing_time_interval            => $self->_processing_time_interval(),
                    selection_datetime                  => $self->_selection_datetime(),
                },
            }
        },
        result  => {
            sla_datetime => $self->_selection_datetime_plus_processing_time()
        },
    }) {
        subtest $test->{name} => sub {
            note(sprintf('Starting subtest %s', $test->{name}));
            my $mock_shipment = Test::MockObject::Builder->extend(
                $data_helper->create_shipment(), $test->{setup}->{shipment}
            );

            my $sla_datetime = $mock_shipment->get_sla_datetime();

            is("$sla_datetime", $test->{result}->{sla_datetime} . '',
                'Returned date is as expected');
        };
    }
}

package Test::XTracker::Schema::ResultSet::SOS::TruckDeparture;
use NAP::policy qw/tt test class/;
use Test::XTracker::LoadTestConfig;
use DateTime;
use DateTime::Duration;
use DateTime::Format::DateParse;
use Test::MockObject::Builder;
use XTracker::Config::Local qw(local_timezone);

BEGIN {
    extends 'NAP::Test::Class';

    use Test::SOS::Data;
    has 'data_helper' => (
        is => 'ro',
        default => sub { Test::SOS::Data->new() },
    );
};

sub test__get_truck_departure_no_exceptions :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => 'Ensure departures are filtered by carrier, archived entries are '
                . 'ignored, begin and end times are honoured and last truck of day is '
                . 'picked when processing time indicates',
            setup   => {
                carriers => [ 'BigCarrier', 'LittleCarrier' ],
                truck_departures_by_class => {
                    Cheap       => [
                        {
                            # departure time that should be ignored because it is after
                            # the (selection_time + processing_time)
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            end_date    => { year => 2014, month => 6, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 13 },
                        },
                        {
                            # departure time that should be ignored because the current
                            # processing-time indicates we should use the last departure
                            # time of the day (which this is not)
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            end_date    => { year => 2014, month => 6, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 16 },
                        },
                        {
                            # The correct departure time because it is the correct carrier,
                            # after the (selection_time + processing_time) and the last
                            # valid truck of the day
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            end_date    => { year => 2014, month => 6, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 18 },
                        },
                        {
                            # departure time that should be ignored because it is the
                            # wrong carrier
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            end_date    => { year => 2014, month => 6, day => 1, hour => 1 },
                            carrier         => 'LittleCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 19 },
                        },
                        {
                            # departure time that should be ignored because it has been
                            # archived
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            end_date    => { year => 2014, month => 6, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 20 },
                            archived_datetime => { year => 2014, month => 2, day => 2, hour => 1 }
                        },
                        {
                            # departure time that should be ignored because the 'begin_date'
                            # is after the (selection_datetime + processing_time)
                            begin_date  => { year => 2014, month => 4, day => 1, hour => 1 },
                            end_date    => { year => 2014, month => 6, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 21 },
                        },
                        {
                            # departure time that should be ignored because the 'end_date'
                            # is before the (selection_datetime + processing_time)
                            begin_date  => { year => 2013, month => 11, day => 1, hour => 1 },
                            end_date    => { year => 2013, month => 12, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 22 },
                        },
                    ],
                },
                get_truck_departure_params => {
                    selection_datetime  => { year => 2014, month => 3, day => 10, hour => 12 }, # Monday
                    processing_times     => {
                        processing_time => { hours => 2 },
                        use_first_truck => 0,
                    },
                    carrier             => 'BigCarrier',
                    shipment_class      => 'Cheap',
                },
            },
            result => {
                # This is the same day as the selection date, but the time matches that of
                # the correct departure time (as noted above)
                correct_departure_datetime => { year => 2014, month => 3, day => 10, hour => 18 },
            },
        },

        {
            name    => 'Ensure first truck processing time parameter is honoured and '
                . 'that NULL end_dates are assumed to be valid',
            setup   => {
                carriers => [ 'BigCarrier' ],
                truck_departures_by_class => {
                    Cheap       => [
                        {
                            # This departure time should be ignored as it is before the
                            # (selection_datetime + processing_time)
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 8 },
                        },
                        {
                            # This is the correct departure time because the begin_date
                            # is in the past, there is no end_date, it is the correct
                            # carrier and it is the first available truck after the
                            # (selection_datetime + processing_time)
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 13 },
                        },
                        {
                            # departure time that should be ignored because there is an
                            # earlier valid truck time (as noted above)
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 15 },
                        },
                    ],
                },
                get_truck_departure_params => {
                    selection_datetime  => { year => 2014, month => 3, day => 10, hour => 10 }, # Monday
                    processing_times     => {
                        processing_time => { hours => 2 },
                        use_first_truck => 1,
                    },
                    carrier             => 'BigCarrier',
                    shipment_class      => 'Cheap',
                },
            },
            result => {
                # This is the same day as the selection date, but the time matches that of
                # the correct departure time (as noted above)
                correct_departure_datetime => { year => 2014, month => 3, day => 10, hour => 13 },
            },
        },
        {
            name    => 'Ensure that when there are no departures on the day of processing'
                . ' that the last one the next available day is selected',
            setup   => {
                carriers => [ 'BigCarrier' ],
                truck_departures_by_class => {
                    Cheap       => [
                        {
                            # This departure time should be ignored as it is after the
                            # (selection_datetime + processing_time)
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 8 },
                        },
                        {
                            # departure time that should be ignored because we should pick
                            # the last departure time of the day
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Tuesday',
                            departure_time  => { hours => 7 },
                        },
                        {
                            # This is the correct departure time because it is the last
                            # departure time available on the first available day (we
                            # select the first truck time of the day as this is not the
                            # day processing finished)
                           begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Tuesday',
                            departure_time  => { hours => 16 },
                        },
                    ],
                },
                get_truck_departure_params => {
                    selection_datetime  => { year => 2014, month => 3, day => 10, hour => 10 }, # Monday
                    processing_times     => {
                        processing_time => { hours => 2 },
                        use_first_truck => 0,
                    },
                    carrier             => 'BigCarrier',
                    shipment_class      => 'Cheap',
                },
            },
            result => {
                # This is the day after day the selection date, and the time matches that of
                # the correct departure time (as noted above)
                correct_departure_datetime => { year => 2014, month => 3, day => 11, hour => 16 },
            },
        }
    ) {
        subtest $test->{name} => sub {
            my $truck_departure_rs = $self->_create_test_departure_rs($test);

            my $departure_datetime
                = $truck_departure_rs->get_truck_departure_datetime($self->_create_params($test));

            my $expected_datetime = DateTime->new($test->{result}->{correct_departure_datetime});
            is("$departure_datetime", "$expected_datetime",
                'Truck departure time is as expected');
        };
    }
}

sub test__get_truck_departure_with_exceptions :Tests {
    my ($self) = @_;

    for my $test (
        {
            name    => '',
            setup   => {
                carriers => [ 'BigCarrier' ],
                truck_departures_by_class => {
                    Cheap       => [
                        # Both of these scheduled truck times should be ignored as there
                        # are valid exceptions defined below
                        {
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 12 },
                        },
                        {
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 16 },
                        },
                        # Teh below truck time is ignored as there are available exceptions
                        {
                            begin_date  => { year => 2014, month => 2, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 12 },
                        },
                    ],
                },
                truck_departure_exceptions_by_class => {
                    Cheap => [
                        # This departure should be ignored because there is a later
                        # truck time (and the processing time dictates we should use
                        # the last truck)
                        {
                            exception_date  => { year => 2014, month => 2, day => 1 },
                            carrier         => 'BigCarrier',
                            departure_time  => { hours => 13 },
                        },
                        # This is the correct departure as it is the last departure of
                        # the day
                        {
                            exception_date  => { year => 2014, month => 2, day => 1 },
                            carrier         => 'BigCarrier',
                            departure_time  => { hours => 14 },
                        },
                        # This departure should be ignored because it has an archived_datetime
                        {
                            exception_date      => { year => 2014, month => 2, day => 1 },
                            carrier             => 'BigCarrier',
                            departure_time      => { hours => 15 },
                            archived_datetime   => { year => 2014, month => 1, day => 1, hour => 1 },
                        },
                    ],
                },
                get_truck_departure_params => {
                    selection_datetime  => { year => 2014, month => 2, day => 1, hour => 9 }, # Monday
                    processing_times     => {
                        processing_time => { hours => 2 },
                        use_first_truck => 0,
                    },
                    carrier             => 'BigCarrier',
                    shipment_class      => 'Cheap',
                },
            },
            result => {
                # This is the same day as the selection date, but the time matches that of
                # the correct departure time (as noted above)
                correct_departure_datetime => { year => 2014, month => 2, day => 1, hour => 14 },
            },
        },

        {
            name    => 'Ensure days with a blank exception are treated as having no truck'
            . ' departures',
            setup   => {
                carriers => [ 'BigCarrier' ],
                truck_departures_by_class => {
                    Cheap       => [
                        # Both of these scheduled truck times should be ignored as there
                        # exists a 'blank' exception for this date (which means there are
                        # no truck departures on that day)
                        {
                            begin_date  => { year => 2014, month => 1, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 12 },
                        },
                        {
                            begin_date  => { year => 2014, month => 1, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 16 },
                        },
                        # This is the correct truck time as the 'blank' exception means
                        # there are no departures the day before
                        {
                            begin_date  => { year => 2014, month => 1, day => 1, hour => 1 },
                            carrier         => 'BigCarrier',
                            week_day        => 'Tuesday',
                            departure_time  => { hours => 18 },
                        },
                    ],
                },
                truck_departure_exceptions_by_class => {
                    Cheap => [
                        # This exception means there are no departures on this day
                        {
                            exception_date  => { year => 2014, month => 2, day => 3 },
                            carrier         => 'BigCarrier',
                        },
                    ],
                },
                get_truck_departure_params => {
                    selection_datetime  => { year => 2014, month => 2, day => 3, hour => 9 }, # Monday
                    processing_times     => {
                        processing_time => { hours => 2 },
                        use_first_truck => 0,
                    },
                    carrier             => 'BigCarrier',
                    shipment_class      => 'Cheap',
                },
            },
            result => {
                # This is the day after the selection date, as the exception means there
                # are no actual trucks that day. So we use the one the day after
                correct_departure_datetime => { year => 2014, month => 2, day => 4, hour => 18 },
            },
        }
    ) {
        subtest $test->{name} => sub {
            my $truck_departure_rs = $self->_create_test_departure_rs($test);

            my $departure_datetime
                = $truck_departure_rs->get_truck_departure_datetime($self->_create_params($test));

            my $expected_datetime = DateTime->new($test->{result}->{correct_departure_datetime});
            is("$departure_datetime", "$expected_datetime",
                'Truck departure time is as expected');
        };
    }
}

sub test__truck_departure_events :Tests {
    my ( $self ) = @_;

    for my $test (
        {
            # Let's make sure that if x truck departures exist over
            # a date range, we bring back x truck departure events
            # within that range
            name    =>  "Check departure event date range boundaries",
            setup   => {
                carriers => [ 'AnyCarrier' ],
                truck_departures_by_class => {
                    SomeClass       => [
                        # Make sure there are departures on two adjacent days
                        {
                            begin_date  => { year => 2012, month => 1, day => 1, hour => 1 },
                            carrier         => 'AnyCarrier',
                            week_day        => 'Monday',
                            departure_time  => { hours => 12 },
                        },
                        {
                            begin_date  => { year => 2012, month => 1, day => 1, hour => 1 },
                            carrier         => 'AnyCarrier',
                            week_day        => 'Tuesday',
                            departure_time  => { hours => 12 },
                        },
                    ],
                },
                get_truck_departure_event_parameters => {
                    # Start of Tuesday 29/04/14
                    start => { year => 2014, month => 4, day => 29 },
                    # End of Monday 02/06/14
                    end => {
                        year    => 2014,
                        month   => 6,
                        day     => 2,
                        hour    => 23,
                        minute  => 59,
                        second  => 59,
                    },
                },
            },
            result  => {
                # There are now 10 Monday/Tuesday departures in the above interval
                expected_event_count => 10,
            }
        },
        {
            # If departures exist for a date, a single exception
            # should override those departures
            name    => "Check truck departure events exhibit exceptions",
            setup   => {
                carriers    => ['OrdinaryCarrier', 'ExceptionalCarrier'],
                truck_departures_by_class => {
                    SomeClass       => [
                        # Two departures on a Wednesday
                        {
                            begin_date  => { year => 2012, month => 1, day => 1, hour => 1 },
                            carrier         => 'OrdinaryCarrier',
                            week_day        => 'Wednesday',
                            departure_time  => { hours => 12 },
                        },
                        {
                            begin_date  => { year => 2012, month => 1, day => 1, hour => 1 },
                            carrier         => 'OrdinaryCarrier',
                            week_day        => 'Wednesday',
                            departure_time  => { hours => 14 },

                        },
                    ],
                },
                truck_departure_exceptions_by_class => {
                    SomeClass => [
                        # One exception
                        {
                            exception_date  => { year => 2014, month => 4, day => 30 },
                            carrier         => 'ExceptionalCarrier',
                            departure_time  => { hours => 14 },
                        }
                    ],
                },
                get_truck_departure_event_parameters => {
                    # Start of Wednesday (30/04/14)
                    start   => { year => 2014, month => 4, day => 30 },
                    # End of same Wednesday
                    end => {
                        year    => 2014,
                        month   => 4,
                        day     => 30,
                        hour    => 23,
                        minute  => 59,
                        second  => 59,
                    },
                },
            },
            result  => {
                # The single exception should add an extra truck that day
                expected_event_count => 3,
            }
        },
        {
            # If departures exist for a date, a null exception
            # should result in no departures for that day for that carrier
            name    => "Check truck departure events are suppressed by null exceptions",
            setup   => {
                carriers    => ['OrdinaryCarrier', 'ExceptionalCarrier'],
                truck_departures_by_class => {
                    SomeClass       => [
                        # Two departures on a Thursday
                        {
                            begin_date  => { year => 2012, month => 1, day => 1, hour => 1 },
                            carrier         => 'OrdinaryCarrier',
                            week_day        => 'Thursday',
                            departure_time  => { hours => 12 },
                        },
                        {
                            begin_date  => { year => 2012, month => 1, day => 1, hour => 1 },
                            carrier         => 'ExceptionalCarrier',
                            week_day        => 'Thursday',
                            departure_time  => { hours => 14 },

                        },
                    ],
                },
                truck_departure_exceptions_by_class => {
                    SomeClass => [
                        # A null exception (no set departure time)
                        {
                            exception_date  => { year => 2014, month => 5, day => 8 },
                            carrier         => 'ExceptionalCarrier',
                        }
                    ],
                },
                get_truck_departure_event_parameters => {
                    # Start of Thursday (08/05/14)
                    start   => { year => 2014, month => 5, day => 8 },
                    # End of the same day
                    end => {
                        year    => 2014,
                        month   => 5,
                        day     => 8,
                        hour    => 23,
                        minute  => 59,
                        second  => 59,
                    },
                },
            },
            result  => {
                # No ExceptionalCarrier trucks for you today
                expected_event_count => 1,
            }
        },
        {
            # If an expired exception exists for a date, the departures
            # for that date should be unaffected
            name    => "Check expired exceptions do not exhibit in events",
            setup   => {
                carriers    => ['OrdinaryCarrier', 'ExceptionalCarrier'],
                truck_departures_by_class => {
                    SomeClass       => [
                        # Two departures on a Friday
                        {
                            begin_date  => { year => 2012, month => 1, day => 1, hour => 1 },
                            carrier         => 'OrdinaryCarrier',
                            week_day        => 'Friday',
                            departure_time  => { hours => 12 },
                        },
                        {
                            begin_date  => { year => 2012, month => 1, day => 1, hour => 1 },
                            carrier         => 'OrdinaryCarrier',
                            week_day        => 'Friday',
                            departure_time  => { hours => 14 },

                        },
                    ],
                },
                truck_departure_exceptions_by_class => {
                    SomeClass => [
                        # An archived exception
                        {
                            exception_date  => { year => 2014, month => 5, day => 16 },
                            carrier         => 'ExceptionalCarrier',
                            archived_datetime   => { year => 2014, month => 1, day => 1, hour => 1 },
                        }
                    ],
                },
                get_truck_departure_event_parameters => {
                    # Start of Friday (16/05/14)
                    start   => { year => 2014, month => 5, day => 16 },
                    # End of the same day
                    end => {
                        year    => 2014,
                        month   => 5,
                        day     => 16,
                        hour    => 23,
                        minute  => 59,
                        second  => 59,
                    },
                },
            },
            result  => {
                # Exception has no effect; two extant truck departures are exhibited
                expected_event_count => 2,
            }
        }
    ) {
        subtest $test->{name} => sub {
            # create and retrieve test departures
            my $truck_departure_rs = $self->_create_test_departure_rs($test);

            # set up start and end dates (00:00:00 on the first and last day of the range of dates)
            my $start = DateTime->new( $test->{setup}->{get_truck_departure_event_parameters}->{start} );
            my $end = DateTime->new( $test->{setup}->{get_truck_departure_event_parameters}->{end} );

            # Make sure these times are in the time zone of the DC
            $start->set_time_zone( local_timezone() );
            $end->set_time_zone( local_timezone() );

            my @departure_events = $truck_departure_rs->get_truck_departure_events($start, $end);

            # check we have an expected number of returned event objects
            is(scalar(@departure_events), $test->{result}->{expected_event_count},
                "Correct number of truck departure events returned");

            # check all events are in range
            my $all_in_range = 1;
            my @out_of_range;
            for my $event (@departure_events) {
                my $departure_time = $event->departure_time;
                # The +1 day is not a fudge. The $start and $end variables identify
                # the start and endpoints of a range of whole days, and valid
                # results can take any value within those days, so can be up to
                # 24 hours after $end (but not before $start, since it's truncated).
                if ($departure_time->epoch() > $end->add( days => 1 )->epoch() || $departure_time->epoch() < $start->epoch()) {
                    $all_in_range = 0;
                    # Assemble all calendar events that are outside the range
                    # (not the event object itself, as that'll dump the schema)
                    push( @out_of_range, explain($event->as_calendar_event) );
                }
            }

            ok($all_in_range, "All truck departure events are in range") or diag (@out_of_range);
        }
    }
}

sub _create_test_departure_rs {
    my ($self, $test) = @_;

    for my $carrier_name (@{$test->{setup}->{carriers}}) {
        $self->data_helper->find_or_create_carrier({ name => $carrier_name });
    }

    my @truck_departure_ids;

    for my $class_name (keys %{$test->{setup}->{truck_departures_by_class}}) {
        my $class_object = $self->data_helper->find_or_create_shipment_class({
            name => $class_name,
        });

        my $truck_departure_defs = $test->{setup}->{truck_departures_by_class}->{$class_name};

        for my $truck_departure_def (@$truck_departure_defs) {
            push @truck_departure_ids, $self->data_helper->create_truck_departure({
                %$truck_departure_def,
                shipment_classes => [$class_name],
            })->id();
        }
    }

    my @truck_departure_exception_ids;

    for my $class_name (keys %{$test->{setup}->{truck_departure_exceptions_by_class}}) {
        my $class_object = $self->data_helper->find_or_create_shipment_class({
            name => $class_name,
        });

        my $truck_departure_exception_defs = $test->{setup}->{truck_departure_exceptions_by_class}->{$class_name};

        for my $truck_departure_exception_def (@$truck_departure_exception_defs) {
            push @truck_departure_exception_ids, $self->data_helper->create_truck_departure_exception({
                %$truck_departure_exception_def,
                shipment_classes => [$class_name],
            })->id();
        }
    }

    my $truck_departure_exception_rs;
    if(@truck_departure_exception_ids) {
        $truck_departure_exception_rs = $self->schema->resultset('SOS::TruckDepartureException')->search({
            'me.id' => \@truck_departure_exception_ids,
        });
    } else {
        # If we have no exceptions defined, make sure nothing useful is ever returned by
        # filtering the current db by only those with an archived date
        $truck_departure_exception_rs = $self->schema->resultset('SOS::TruckDepartureException')->search({
            'me.archived_datetime' => { '!=' => undef },
        });
    }

    my $truck_departure_rs = $self->schema->resultset('SOS::TruckDeparture')->search({
        'me.id' => \@truck_departure_ids,
    });
    $truck_departure_rs->truck_departure_exception_rs($truck_departure_exception_rs);
    return $truck_departure_rs;
}

sub _create_params {
    my ($self, $test) = @_;

    my $param_defs = $test->{setup}->{get_truck_departure_params};

    return {
        selection_datetime  => DateTime->new($param_defs->{selection_datetime}),
        processing_times    => Test::MockObject::Builder->build({
            set_isa             => 'XTracker::Schema::ResultSet::SOS::ProcessingTime',
            validation_class    => 'XTracker::Schema::ResultSet::SOS::ProcessingTime',
            mock                => {
                use_first_truck         => $param_defs->{processing_times}->{use_first_truck},
                processing_time_duration=> DateTime::Duration->new($param_defs->{processing_times}->{processing_time}),
            },
        }),
        carrier             => $self->data_helper->find_or_create_carrier({
            name => $param_defs->{carrier},
        }),
        shipment_class      => $self->data_helper->find_or_create_shipment_class({
            name => $param_defs->{shipment_class},
        }),
    };
}

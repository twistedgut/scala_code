package XTracker::Schema::ResultSet::SOS::TruckDeparture;
use parent 'DBIx::Class::ResultSet';
use NAP::policy qw/tt/;
use Moose;
use MooseX::NonMoose;

use MooseX::Params::Validate;
use DateTime::Duration;
use DBIx::Class::InflateColumn::Time;
use DateTime;
use DateTime::Duration;
use SOS::TruckDepartureEvent;
use XTracker::Config::Local qw(config_var);

has 'truck_departure_exception_rs' => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        return $self->result_source->schema->resultset('SOS::TruckDepartureException')->search_rs();
    },
);

=head1 NAME

XTracker::Schema::ResultSet::SOS::TruckDeparture

=head1 DESCRIPTION

Defines specialised methods for the TruckDeparture resultset

=head1 PUBLIC METHODS

=head2 get_truck_departure_datetime

Selects a suitable truck departure given shipment data

Note that this method does not care what date or time it is NOW, and will happily select a
truck that has already left. This is ok as we are only using this to work out an SLA and
if this turns out to be in the past then that shipment must already be very late!

    param - selection_datetime : The datetime at which the shipment would be selected
    param - processing_times : The processing time resultset representing the shipment
    param - carrier : The carrier that will fulfil the delivery
    param - shipment_class : Shipment class representing what the customer picked for delivery

    return - $departure_datetime : A datetime object that represents the actual departure time

=cut

sub get_truck_departure_datetime {
    my ($self, $selection_datetime, $processing_times, $carrier, $shipment_class)
        = validated_list(\@_,
        selection_datetime  => { isa => 'DateTime' },
        processing_times    => { isa => 'XTracker::Schema::ResultSet::SOS::ProcessingTime' },
        carrier             => { isa => 'XTracker::Schema::Result::SOS::Carrier' },
        shipment_class      => { isa => 'XTracker::Schema::Result::SOS::ShipmentClass' },
    );

    # Work out what time we can expect this shipment to have been processed
    my $target_processed_datetime = $selection_datetime->clone()->add_duration(
        $processing_times->processing_time_duration()
    );

    # See if there are any trucks we can make on the day that the shipment completed
    # processing. Depending on the shipment's 'processing_time' object, we might want
    # go for either the first truck available or the last truck of the day.
    my $earliest_departure_datetime = $target_processed_datetime->clone();
    my $truck_departure_time = $self->_get_truck_departure_time({
        carrier                     => $carrier,
        class                       => $shipment_class,
        earliest_departure_datetime => $earliest_departure_datetime,
        use_first_truck             => $processing_times->use_first_truck(),
        processed_datetime          => $target_processed_datetime,
    });

    # All future uses of this datetime will after the processing date and therefore
    # can be at any time of day
    $earliest_departure_datetime->set_hour(0);
    $earliest_departure_datetime->set_minute(0);
    $earliest_departure_datetime->set_second(0);
    $earliest_departure_datetime->set_nanosecond(0);

    my $days_after_processed_date = 0;
    while (!$truck_departure_time && $days_after_processed_date <= 6) {
        # If there was no available truck on the day the shipment finished being
        # processed, we check each of the next 6 days until we find one.
        # For these days we'll always go for the first truck available
        $earliest_departure_datetime->add({ days => 1});
        $truck_departure_time = $self->_get_truck_departure_time({
            carrier                     => $carrier,
            class                       => $shipment_class,
            earliest_departure_datetime => $earliest_departure_datetime,
            use_first_truck             => $processing_times->use_first_truck(),
            processed_datetime          => $target_processed_datetime,
        });
        $days_after_processed_date++;
    }

    # Work out the exact departure_datetime if we found a truck
    my $departure_datetime;
    if ($truck_departure_time) {
        $departure_datetime = $target_processed_datetime->clone->add(
            days => $days_after_processed_date,
        )->set(
            hour    => $truck_departure_time->hours(),
            minute  => $truck_departure_time->minutes(),
            second  => $truck_departure_time->seconds(),
        );
    }

    return $departure_datetime;
}

=head2 get_truck_departure_events

Returns an array of TruckDepartureEvent objects for a date range, given the restricted by the current resultset

=cut

sub get_truck_departure_events {
    my ( $self, $start, $end ) = @_;

    # All calculations in dc-local timezone
    $start->set_time_zone( config_var('DistributionCentre', 'timezone') );
    $end->set_time_zone( config_var('DistributionCentre', 'timezone') );

    my $delta = $start->delta_days($end)->in_units('days');
    my $schema = $self->result_source->schema;
    my $dtf = $schema->storage->datetime_parser;
    my $exceptions_rs = $self->truck_departure_exception_rs();

    my @events;

    # Iterate over days in the date range

    for my $day_offset (0 .. $delta) {
        # Truncate to 00:00:00
        my $active_day = $start->clone()->add(days => $day_offset)->truncate( to => 'day');
        my $active_day_date_string = $dtf->format_datetime($active_day);

        # Add non-null exceptions to events
        my @exceptions = $exceptions_rs->search( {
            'me.exception_date'     => $active_day_date_string,
            'me.archived_datetime'  => undef,
        });

        my $excepted_carriers = {};

        for my $except (@exceptions) {  # Append exceptions

            $excepted_carriers->{$except->carrier_id()} = 1;

            # Get shipment classes
            my $shipment_classes = $except->truck_departure_exception__shipment_classes->search_related('shipment_class');
            push( @events, SOS::TruckDepartureEvent->new(
                carrier             =>  $except->carrier,
                shipment_class_rows =>  [ $shipment_classes->all() ],
                departure_time      =>  $active_day->clone()->add_duration($except->departure_time),
            )) if $except->departure_time();
        }

        # Don't include the regularly scheduled trucks for the carriers we have exceptions
        # for
        my @excepted_carrier_ids = keys %$excepted_carriers;

        # Get applicable departures
        my $week_day_rs = $self->result_source->schema->resultset('SOS::WeekDay');
        my @departure_rows = $self->search({
            'week_day_id'           =>      $week_day_rs->get_sos_week_day_from_datetime( datetime => $active_day )->id,
            'me.archived_datetime'  =>      undef,
            'me.begin_date'         =>      { '<='  => $active_day_date_string },
            -or => [
                'me.end_date'       =>      { '>'   => $active_day_date_string },
                'me.end_date'       =>      undef,
            ],
            -not => {
                'me.carrier_id'     =>      \@excepted_carrier_ids,
            }
        });

        for my $departure_row (@departure_rows){ # Append departures

            # Get shipment classes
            my $shipment_classes = $departure_row->truck_departure__shipment_classes->search_related('shipment_class');
            my $event_dt = $active_day->clone()->add_duration($departure_row->departure_time);

            # Check datetimes are in the ($start, $end) range, and append
            # if they are. (This whole iterative process requires a range
            # of whole days to operate over, so that range might exceed
            # the boundaries of what was requested
            if (DateTime->compare($start, $event_dt) < 1 && DateTime->compare($event_dt, $end) < 1) {
                push( @events, SOS::TruckDepartureEvent->new(
                    carrier             =>  $departure_row->carrier,
                    shipment_class_rows =>  [ $shipment_classes->all() ],
                    departure_time      =>  $event_dt,
                    )
                );
            }
        }
    }

    return @events;
}

# This will only look for departures on the same day as 'earliest_departure_datetime'
sub _get_truck_departure_time {
    my ($self, $args) = @_;

    my $earliest_time_duration = $self->_format_duration(DateTime::Duration->new(
        hours   => $args->{earliest_departure_datetime}->hour(),
        minutes => $args->{earliest_departure_datetime}->minute(),
    ));

    # See if exceptions override this specific date
    my $truck_departure_exception_rs = $self->truck_departure_exception_rs->search({
        'me.carrier_id'                                                 => $args->{carrier}->id(),
        'truck_departure_exception__shipment_classes.shipment_class_id' => $args->{class}->id(),
        'me.exception_date'                                             => $args->{earliest_departure_datetime},
        'me.archived_datetime'                                          => undef,
    }, {
        join => ['truck_departure_exception__shipment_classes'],
    });

    if ($truck_departure_exception_rs->count()) {
        # Overrides exist, see if any are valid for the shipment
        my $truck_departure_exception = $truck_departure_exception_rs->search({
            'me.departure_time'                                             => {
                '>=' => $earliest_time_duration,
            },
        }, {
            order_by => { ($args->{use_first_truck} ? '-asc' : '-desc') => 'me.departure_time' },
            rows => 1,
        })->first();

        return $truck_departure_exception->departure_time() if $truck_departure_exception;

        # If we get here, there are exceptions defined for the day, but either they are
        # all too late, or a 'blank' exception has been created (i.e. the departure_time
        # column is NULL). The latter means there are no truck departures on this day
        return undef;
    }

    my $week_day = $self->_get_week_day($args->{earliest_departure_datetime});

    # No exceptions, so look at the regular schedule
    my $truck_departure = $self->search({
        'me.carrier_id'                                 => $args->{carrier}->id(),
        'truck_departure__shipment_classes.shipment_class_id'    => $args->{class}->id(),
        'me.week_day_id'                                => $week_day->id(),
        'me.departure_time'                             => {
            '>=' => $earliest_time_duration,
        },
        'me.archived_datetime' => undef,
        'me.begin_date' => { '<=' => $args->{processed_datetime} },
        -or => [
            'me.end_date' => { '>' => $args->{processed_datetime} },
            'me.end_date' => undef,
        ],
    }, {
        join => ['truck_departure__shipment_classes'],
        order_by => { ($args->{use_first_truck} ? '-asc' : '-desc') => 'me.departure_time' },
        rows => 1,
    })->first();

    return ($truck_departure
        ? $truck_departure->departure_time()
        : undef
    );
}

sub _format_duration {
    my ($self, $duration) = @_;

    # Naughty, but ensures that we're using the same format as when we set a Duration
    # on this column in the db
    return DBIx::Class::InflateColumn::Time::_deflate($duration);
}

sub _get_week_day {
    my ($self, $datetime) = @_;
    my $schema = $self->result_source->schema;
    return $schema->resultset('SOS::WeekDay')->get_sos_week_day_from_datetime({
        datetime => $datetime,
    });
}

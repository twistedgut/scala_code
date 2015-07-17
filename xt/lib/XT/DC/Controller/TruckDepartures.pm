package XT::DC::Controller::TruckDepartures;
use NAP::policy 'tt', 'class';
use DateTime;
use DateTime::Format::ISO8601;
use XTracker::Config::Local qw(config_var);
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller::REST' }

=head2 calendar_events

Returns a JSON array of calendar events to be displayed in XT
Takes parameters 'start' and 'end' as ISO-8601 datetimes, with
'timezone' as an optional parameter for compatibility reasons,
and retrieves truck departures available between those two
values. Start and end parameters required.

=cut

sub calendar_events :Local :ActionClass('REST') {}

sub calendar_events_GET {
    my ( $self, $c ) = @_;

    # Establish start and end of the period, and the range of days between them

    # Make sure this gets serialised properly if we detach
    $c->res->header('Content-Type' => 'application/json');
    # check values are defined, else return a meaningful error
    unless ($c->req->param('start') && $c->req->param('end')) {
        $self->status_bad_request($c, message => "Undefined parameters");
        $c->stash->{rest} = { error => "Start or end date not defined" };
        $c->detach;
    };

    my $start       = $c->req->param('start');
    my $end         = $c->req->param('end');
    my $timezone    = $c->req->param('timezone');

    my $dt_start = _validate_date($start, $timezone);
    my $dt_end   = _validate_date($end, $timezone);

    # Check dates are defined
    unless ($dt_start && $dt_end) {
        $self->status_bad_request($c, message => "Failed to parse date");
        $c->stash->{rest} = { error => "Failed to parse date"};
        $c->detach;
    }

    # Check start isn't later than end date
    if ( $dt_start->epoch() > $dt_end->epoch() ) {
        $self->status_bad_request($c, message =>"Unordered dates");
        $c->stash->{rest} = { error => "Start date is later than end date"};
        $c->detach;
    }

    # Complain if the request has a range of more than a year
    # (The resultset has to iterate over every day and applicable
    # exception in the range. Allowing arbitrarily large dates is
    # therefore a bad idea)
    if( $dt_start->delta_days($dt_end)->in_units('days') > 366 ) {
        $self->status_bad_request($c, message =>"Excessive range");
        $c->stash->{rest} = { error => "Date range exceeds one year"};
        $c->detach;
    }

    my $schema = $c->model('DB')->schema;
    my $departures_rs = $schema->resultset('SOS::TruckDeparture');

    my @event_objects = $departures_rs->get_truck_departure_events($dt_start, $dt_end);
    my @events = map { $_->as_calendar_event } @event_objects;

    # response needs to be a JSON array
    my $json =  [ @events ] ;
    $c->stash(json => $json);
    $c->forward('/serialize');
}

sub _validate_date {
    my ($date, $timezone) = @_;

    # If the optional timezone parameter is undefined,
    # set it to the most sensible value given the context:
    # the local time zone of the DC this is running on.
    $timezone = $timezone ?
        $timezone : config_var('DistributionCentre', "timezone");

    # Parse the date or return undef; errors are handled downstream
    my $datetime;
    try {
        $datetime = DateTime::Format::ISO8601->parse_datetime($date);
    } catch {
        return undef;
    };
    # The optional time zone only gets used if the parsed datetime
    # doesn't have its own
    if ($datetime->time_zone->name eq 'floating') {
       $datetime->set_time_zone($timezone);
    }

    return $datetime;
}

1;

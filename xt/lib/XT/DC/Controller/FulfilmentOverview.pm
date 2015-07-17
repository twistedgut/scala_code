package XT::DC::Controller::FulfilmentOverview;
use NAP::policy qw/class/;

=head1 NAME

XT::DC::Controller::FulfilmentOverview

=head1 DESCRIPTION

Overview of fulfilment, i.e. a list of trucks that are about to depart
and a list of shipments that are yet to be dispatched - a summary of information
that can also be found on the individual Selection, Picking, Packing, Labelling
and Dispatch pages.

=cut

use XTracker::Config::Local qw(config_var local_timezone);
use DateTime;
use DateTime::Format::DateParse;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET);
use JSON qw( decode_json );
use XTracker::Constants  qw( :sos_carrier_map );
use XTracker::Constants::FromDB qw( :fulfilment_overview_stage );

BEGIN { extends 'Catalyst::Controller' }

sub root : Chained('/') PathPart('Fulfilment/FulfilmentOverview') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    $c->check_access('Fulfilment', 'Fulfilment Overview');

}

=item B<truck_departures>

Action for Fulfilment/FulfilmentOverview

=cut

sub truck_departures : Chained('root') PathPart('') Args(0) ActionClass('REST') {
    my ($self, $c) = @_;

    $c->stash(
        timezone => config_var("DistributionCentre", "timezone"),
    );
}

=head2 truck_departures_GET

GET REST action for Fulfilment/FulfilmentOverview.

Populates the edit form with the details of the box to be edited, as well as the
box or inner box details for the other boxes of the channel.

=cut

sub truck_departures_GET {
    my ( $self, $c ) = @_;

    my $schema = $c->model('DB')->schema;
    my $dt_start = $schema->db_now();
    my $fulfilment_days = $c->req->param('number_of_days') // 3;

    my $enabled_full_channels = $schema->resultset('Public::Channel')->enabled(1);

    my $channel_ids = $c->req->params->{channel_id}
        // [$enabled_full_channels->get_column('id')->all];
    $channel_ids = (ref($channel_ids) eq 'ARRAY' ? $channel_ids : [$channel_ids]);

    my $dt_end = $schema->db_now()->add( days => $fulfilment_days )->truncate( to => 'day');
    my $truck_departure_events = $self->get_truck_departure_events( $c, $dt_start, $dt_end );
    my $truck_shipments_rs = $schema->resultset('Public::Shipment');
    my $truck_departure_shipments = {};

    for my $event ( @{ $truck_departure_events } ) {
        my $carrier    = $event->{carrier};
        my $sla_cutoff = $event->{departure_time};
        my $sla_cutoff_parameters = $self->process_sla_cutoff_datetime( $sla_cutoff, $dt_start );
        my $sla_date = $sla_cutoff_parameters->{sla_date};
        my $sla_time = $sla_cutoff_parameters->{sla_time};

        my @shipment_objects = $truck_shipments_rs->get_fulfilment_overview_list({
            carrier_ids => $SOS_CARRIER_TO_XT_CARRIER_MAP->{$carrier},
            sla_cutoff  => $sla_cutoff,
        })->search_by_channel_ids($channel_ids);
        my $shipment_item_statuses = $truck_shipments_rs->get_shipment_item_statuses( \@shipment_objects );
        $shipment_item_statuses->{'sla_countdown'} = $sla_cutoff_parameters->{sla_countdown};
        $truck_departure_shipments->{$sla_date}->{$sla_time}->{$carrier} = $shipment_item_statuses
            if $shipment_item_statuses->{shipments_total};
    }
    my $overview_stage_rs = $schema->resultset('Public::FulfilmentOverviewStage');
    my @late_shipments = $truck_shipments_rs->get_fulfilment_overview_list({})->search_by_channel_ids($channel_ids);
    $c->stash(
        late_shipments          => $truck_shipments_rs->get_shipment_item_statuses(\@late_shipments),
        dispatched_stage_id     => $FULFILMENT_OVERVIEW_STAGE__DISPATCHED,
        truck_departures        => $truck_departure_shipments,
        shipment_stage_map      => $overview_stage_rs->id_stage_name(),
        fulfilment_days         => $fulfilment_days,
        title                   => 'Truck Departures',
        channels                => [$enabled_full_channels->all],
        selected_channels       => $channel_ids,
    );

    return;
}

=head2 process_sla_cutoff_datetime

Convert sla_cutoff into a hash of parameters, which is returned:
sla_date -> the SLA date
sla_time -> the SLA time
sla_countdown -> the time in days (if applicable), hours and minutes to the sla cutoff

=cut

sub process_sla_cutoff_datetime {
    my ( $self, $sla_cutoff, $dt_start ) = @_;

    my $sla_cutoff_dt = DateTime::Format::DateParse->parse_datetime( $sla_cutoff );
    my $sla_parameters = {};

    $sla_parameters->{sla_date} = $sla_cutoff_dt->strftime("%d-%m-%Y");
    $sla_parameters->{sla_time} = $sla_cutoff_dt->strftime("%H:%M:%S");

    my $sla_diff = $sla_cutoff_dt->subtract_datetime($dt_start);
    my $d = DateTime::Format::Duration->new(
        pattern => ($sla_diff->days ? '%e day(s), ' : q{}) . '%H:%M',
        normalise => 1
    );
    $sla_parameters->{sla_countdown} = $d->format_duration($sla_diff);

    return $sla_parameters;
}

=head2 get_truck_departure_events

Use the SOS API to retrieve the truck departure events

=cut

sub get_truck_departure_events {
    my ( $self, $c, $dt_start, $dt_end ) = @_;
    my $truck_api_uri = $c->uri_for('/truckdepartures/calendar_events', { start=> $dt_start, end => $dt_end, timezone =>  $c->stash->{timezone} } );
    my $ua = LWP::UserAgent->new;
    my $truck_api_res = $ua->request(GET $truck_api_uri);
    if ($truck_api_res->is_success) {
        return decode_json( $truck_api_res->content );
    }
    else {
        $c->feedback_warn( "The call to the Truck Departure API was unsuccessful: $truck_api_uri");
        $c->detach;
    }
}

1;

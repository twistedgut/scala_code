package XT::DC::Controller::Admin::TruckDepartures;
use NAP::policy 'tt', 'class';
use XTracker::Config::Local qw(config_var);

BEGIN { extends 'Catalyst::Controller' }

sub index :Path('/Admin/TruckDepartures') :Args(0) {
    my ( $self, $c ) = @_;

    $c->check_access('Admin', 'Truck Departures');
    $c->stash(
        timezone => config_var("DistributionCentre", "timezone"),
        template => 'shared/admin/truckdepartures.tt',
    );
}

1;

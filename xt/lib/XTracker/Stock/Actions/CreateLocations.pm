package XTracker::Stock::Actions::CreateLocations;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Attributes;
use XTracker::Database::Location;
use XTracker::Utilities qw( generate_list get_start_end_location url_encode :string );
use XTracker::Error;
use XTracker::Constants::FromDB qw( :flow_status );

use Data::Dumper;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $auth_level  = $handler->auth_level;
    my $session     = $handler->session;

    if ($auth_level < 3) {
        return $handler->redirect_to('/StockControl/Location/SearchLocationsForm');
    }

    my $changes;
    eval {
        my $guard = $handler->schema->txn_scope_guard;
        # Validate request parameters
        my ($start, $end)       = get_start_end_location($handler->{param_of});

        my $location_type = trim($handler->{param_of}{location_type});

        # this will never be allowed
        die "May not set location type as 'In Transit from IWS'\n"
            if (0+$location_type == $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS);

        # so presumably, neither will this
        die "May not set location type as 'In Transit from PRL'\n"
            if (0+$location_type == $FLOW_STATUS__IN_TRANSIT_FROM_PRL__STOCK_STATUS);

        $changes = create_locations($handler->dbh,
            $start,
            $end,
            $handler->{param_of}{location_type}
        );
        $guard->commit();
    };

    if ($@) {
        # error - redirect back
        xt_warn($@);
    }

    foreach my $new_location (sort(keys(%$changes))) {
        if ($changes->{$new_location} == 1) {
            $session->{message} .= "creating location $new_location<br />";
        } else {
            $session->{message} .= "skipping location $new_location - already exists<br />";
        }
    }

    return $handler->redirect_to('/StockControl/Location?clear_search=1');
}

1;

__END__

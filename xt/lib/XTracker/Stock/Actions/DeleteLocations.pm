package XTracker::Stock::Actions::DeleteLocations;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Attributes;
use XTracker::Database::Location;
use XTracker::Utilities qw( generate_list get_start_end_location url_encode );
use XTracker::Error;

use Data::Dumper;

sub handler {
    my $handler     = XTracker::Handler->new( shift );

    my $auth_level      = $handler->auth_level;
    my $session         = $handler->session;
    my $search_results  = $session->{location_search_results};

    if ($auth_level < 3) {
        return $handler->redirect_to('/StockControl/Location/SearchLocationsForm');
    }

    my $changes;
    my $start;
    my $end;

    my $redir_url           = "";
    my $redir_params        = "";

    my $schema = $handler->schema;
    eval {
        # Validate request parameters
        my $guard = $schema->txn_scope_guard;
        my ($start, $end) = get_start_end_location($handler->{param_of});
        $changes          = delete_locations($schema->storage->dbh, $start, $end);
        $guard->commit;
    };

    if ($@) {
        # error - redirect back
        xt_warn($@);
    }

    foreach my $delete_location (sort(keys(%$changes))) {
        if ($changes->{$delete_location} == 1) {
            $session->{message} .= "deleting location $delete_location<br />";
            delete($search_results->{$delete_location});
        } elsif ($changes->{$delete_location} == 0) {
            $session->{message} .= "skipping location $delete_location - non-existant<br />";
        } elsif ($changes->{$delete_location} == -1) {
            $session->{message} .= "skipping location $delete_location - can't delete non-empty location<br />";
        }
    }

    $session->{location_search_results}     = $search_results;

    if ($handler->{r}->header_in('Referer') =~ m{/SearchLocationsForm$}) {
        $redir_url      = '/StockControl/Location/SearchLocationsForm';
    } else {
        $redir_url      = '/StockControl/Location/DeleteLocationsForm';
    }

    return $handler->redirect_to($redir_url.$redir_params);
}

1;

__END__

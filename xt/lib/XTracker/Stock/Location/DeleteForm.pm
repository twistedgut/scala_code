package XTracker::Stock::Location::DeleteForm;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Navigation qw( get_navtype build_nav build_sidenav );
use XTracker::Stock::Location::Common qw/ :selectable /;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $auth_level  = $handler->auth_level;
    my $session     = $handler->session;

    my $message     = delete($session->{message})   || 0;
    my $view        = $handler->{param_of}{'view'}  || 0;

    if ($auth_level < 3) {
        return $handler->redirect_to('/StockControl/Location/SearchLocationsForm');
    }

    # TT data structure
    $handler->{data}{content}       = 'stocktracker/location/delete.tt';
    $handler->{data}{view}          = $view;
    $handler->{data}{message}       = $message;

    $handler->{data}{floors}            = selectable_floors();
    $handler->{data}{zones}             = selectable_zones();
    $handler->{data}{locations}         = selectable_locations();
    $handler->{data}{levels}            = selectable_levels();

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Location';
    $handler->{data}{subsubsection} = 'Delete';
    $handler->{data}{sidenav}       = build_sidenav({navtype => get_navtype({
            type            => 'location',
            auth_level      => $auth_level})
        });


    $handler->process_template( undef );

    return OK;
}

1;

__END__

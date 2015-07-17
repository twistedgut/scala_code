package XTracker::Stock::Location::PrintForm;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Navigation qw( get_navtype build_sidenav );
use XTracker::PrintFunctions;
use XTracker::PrinterMatrix;
use XTracker::Stock::Location::Common qw/ :selectable /;
use XTracker::Config::Local qw( config_var );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $auth_level      = $handler->auth_level;
    my $session         = $handler->session;

    my $message         = delete($session->{message})   || 0;
    my $view            = $handler->{param_of}{'view'}  || 0;

    my @printers        = XTracker::PrinterMatrix->new->printer_names;

    if ($auth_level < 2) {
        return $handler->redirect_to('/StockControl/Location/SearchLocationsForm');
    }

    # TT data structure
    $handler->{data}{show_new_location_format}
            = config_var('Stock_Location', 'show_barcode_long_location_format');
    $handler->{data}{content}       = 'stocktracker/location/print.tt';
    $handler->{data}{view}          = $view;
    $handler->{data}{message}       = $message;
    $handler->{data}{floors}        = selectable_floors();
    $handler->{data}{zones}         = selectable_zones();
    $handler->{data}{locations}     = selectable_locations();
    $handler->{data}{levels}        = selectable_levels();
    $handler->{data}{units}         = selectable_units();
    $handler->{data}{aisles}        = selectable_aisles();
    $handler->{data}{bays}          = selectable_bays();
    $handler->{data}{positions}     = selectable_positions();

    $handler->{data}{printers}      = \@printers;
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Location';
    $handler->{data}{subsubsection} = 'Print';
    $handler->{data}{sidenav}       = build_sidenav({navtype => get_navtype({
                    type        => 'location',
                    auth_level  => $auth_level})
                });

    $handler->process_template( undef );

    return OK;
}

1;

__END__

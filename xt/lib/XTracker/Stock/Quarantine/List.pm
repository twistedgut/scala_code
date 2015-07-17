package XTracker::Stock::Quarantine::List;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Stock;

use URI;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    # We might want to add a 'quarantine' section one day, but it looks like
    # all RTV currently prints to the same printers, so let's not unnecessarily
    # add more printer entries
    return $handler->redirect_to($handler->printer_station_uri)
        unless $handler->operator->has_location_for_section('rtv_workstation');

    # TODO: Yes there's plenty of redundancy here (we already have
    # $h->printer_station_uri) - the thing is that method creates a uri with a
    # channel_id param (which we don't want) and doesn't set force_selection
    # either. We should address this when we do the cleanup work for printer
    # matrix.
    my $printer_station_uri = URI->new('/My/SelectPrinterStation');
    $printer_station_uri->query_form({
        section         => 'StockControl',
        subsection      => 'Quarantine',
        force_selection => 1,
    });
    $handler->add_to_data({
        section    => 'Stock Control',
        subsection => 'Quarantine',
        content    => 'quarantine/list.tt',
        list       => get_quarantine_stock( $handler->dbh ),
        sidenav    => [{ None => [
            { title => 'Set Quarantine Station', url => $printer_station_uri }
        ]}],
    });

    return $handler->process_template;
}

1;

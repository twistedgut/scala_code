package XTracker::Order::Fulfilment::Airwaybill;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Distribution qw( get_airwaybill_shipment_list );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    return $handler->redirect_to($handler->printer_station_uri)
        unless $handler->operator->has_location_for_section('airwaybill');

    $handler->{data}{section}    = 'Fulfilment';
    $handler->{data}{subsection} = 'Airway Bill';
    $handler->{data}{content}    = 'ordertracker/fulfilment/airwaybill.tt';
    $handler->{data}{shipments}  = get_airwaybill_shipment_list( $handler->{dbh} );

    push @{ $handler->{data}{sidenav}[0]{'None'} }, {
        title => 'Set Airwaybill Station',
        url   => '/My/SelectPrinterStation?section=Fulfilment&subsection=Airwaybill&force_selection=1',
    };
    return $handler->process_template;
}

1;

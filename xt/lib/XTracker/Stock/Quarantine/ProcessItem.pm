package XTracker::Stock::Quarantine::ProcessItem;

use strict;
use warnings;

use URI;

use XTracker::Handler;
use XTracker::Database::Product qw( get_product_data get_product_summary );
use XTracker::Database::Stock 'get_quarantine_stock';

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    # We might want to add a 'quarantine' section one day, but it looks like
    # all RTV currently prints to the same printers, so let's not unnecessarily
    # add more printer entries
    return $handler->redirect_to($handler->printer_station_uri)
        unless $handler->operator->has_location_for_section('rtv_workstation');

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Quarantine';
    $handler->{data}{subsubsection} = 'Process Item';
    $handler->{data}{content}       = 'quarantine/process_item.tt';

    # get quantity id from url
    $handler->{data}{quantity_id} = $handler->{request}->param('id');

    my $printer_station_uri = URI->new('/My/SelectPrinterStation');
    $printer_station_uri->query_form({
        section         => 'StockControl',
        subsection      => 'Quarantine',
        force_selection => 1,
    });
    push @{ $handler->{data}{sidenav}[0]{'None'} },
        { title => 'Back', url => '/StockControl/Quarantine' },
        { title => 'Set Quarantine Station', url => $printer_station_uri };

    # get quarantine info
    my $quarantine = get_quarantine_stock( $handler->dbh );

    foreach my $channel ( keys %{ $quarantine } ) {
        foreach my $id ( keys %{ $quarantine->{$channel} } ) {
            if ($quarantine->{$channel}{$id}{quantity_id} == $handler->{data}{quantity_id}){
                $handler->{data}{info} = $quarantine->{$channel}{$id};
            }
        }
    }

    # product info for display
    my $product = get_product_data($handler->dbh, {
        type => "variant_id", id => $handler->{data}{info}{variant_id}
    });
    $handler->add_to_data({
        product_id => $product->{id},
        %{get_product_summary( $handler->schema, $product->{id} )},
    });

    return $handler->process_template;
}

1;

package XTracker::Order::Fulfilment::DDUHold;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Distribution qw( get_ddu_shipment_list );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'DDU Hold';
    $handler->{data}{content}       = 'ordertracker/fulfilment/dduhold.tt';

    # get list of shipments on DDH hold
    @{$handler->{data}}{qw/channels notify reply/}
        = get_ddu_shipment_list( $handler->{schema} );

    return $handler->process_template;
}

1;

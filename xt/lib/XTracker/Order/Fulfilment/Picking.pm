package XTracker::Order::Fulfilment::Picking;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Distribution qw( get_picking_shipment_list );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{ravni_warning} = 1;
    $handler->{data}{view}          = $handler->{request}->param('view');
    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Picking';

    # hand held version of page
    if ($handler->{data}{view} && ($handler->{data}{view} =~ m{^handheld$}i)){
        $handler->{data}{content} = 'ordertracker/fulfilment/handheld_picking.tt';
    }
    # full screen version of page
    else {
        $handler->{data}{content} = 'ordertracker/fulfilment/picking.tt';

        # get list of shipments at the picking stage to display on screen
        if ($handler->{data}{is_manager}) {

            unless ( $handler->{data}{datalite} ) {
                ($handler->{data}{shipments},        $handler->{data}{staff_shipments},
                 $handler->{data}{sample_shipments}, $handler->{data}{rtv_shipments})
                    = get_picking_shipment_list( $handler->{dbh} );
            }

            if ($handler->iws_rollout_phase > 0) {
                $handler->{data}{shipments} = $handler->{data}{staff_shipments} = $handler->{data}{sample_shipments} = {};
            }
        }
    }
    return $handler->process_template;
}

1;

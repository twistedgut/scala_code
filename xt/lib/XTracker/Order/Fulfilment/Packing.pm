package XTracker::Order::Fulfilment::Packing;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Distribution    qw( get_packing_shipment_list );
use XTracker::Navigation                qw( build_packing_nav );
use NAP::DC::Barcode::Container;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Packing';
    $handler->{data}{content}       = 'ordertracker/fulfilment/packing.tt';

    my $side_nav    = build_packing_nav( $handler->{schema} );
    if ( $side_nav ) {
        $handler->{data}{sidenav}   = [ { 'None' => [ $side_nav ] } ];
    }

    my $c_id=$handler->{param_of}{container_id};
    if ($c_id) {

        # make sure passed container is is valid one and NAP::DC::Barcode
        # is used further down the line
        $c_id = NAP::DC::Barcode::Container->new_from_id($c_id);

        $handler->{data}{container_id}=$c_id;
        $handler->{data}{ask_for_item_barcode}=1;
        $handler->{data}{istransfer} = $handler->{param_of}{istransfer};
        push @{ $handler->{data}{sidenav}[ 0 ]{'None'} }, { title => 'Back', url => "/Fulfilment/Packing" };
    }

    # get list of shipments at the packing stage to display on screen
    if (
        $handler->{data}{is_manager} &&
        (! $handler->{data}{ask_for_item_barcode} ) &&
        (! $handler->{data}{datalite} )
    ) {
        ($handler->{data}{shipments},        $handler->{data}{staff_shipments},
         $handler->{data}{sample_shipments}, $handler->{data}{rtv_shipments})
            = get_packing_shipment_list( $handler->{dbh} );

        # load css & javascript for tab view
        $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
        $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];
    }

    return $handler->process_template;
}

1;

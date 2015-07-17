package XTracker::Order::Fulfilment::PackingException;

use strict;
use warnings;
use XTracker::Handler;
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Database::Distribution    qw(
    get_packing_exception_shipment_list get_orphaned_items
    get_superfluous_item_containers );
use XTracker::Navigation                qw( build_packing_nav );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section} = 'Fulfilment';
    $handler->{data}{subsection} = 'Packing Exception';
    $handler->{data}{content} = 'ordertracker/fulfilment/packing_exception.tt';

    # get list of shipments at the packing stage to display on screen
    if ($handler->{data}{is_manager} &&
        (! $handler->{data}{datalite} )) {

        # Get the list of PE shipments (neither samples nor RTV can be here)
        ($handler->{data}{shipments}, $handler->{data}{staff_shipments})
            = get_packing_exception_shipment_list( $handler->{dbh}, $handler->{schema}, $handler->iws_rollout_phase );

        # Get the list of orphaned items
        $handler->{data}{orphaned_items} =
            get_orphaned_items( $handler->{dbh} );

        # Get the list of containerss containing superfluous. This will need to
        # make a call to 'get_orphaned_items', but as we have that data already,
        # we can pass it in to avoid that
        $handler->{data}{superfluous_item_containers} = get_superfluous_item_containers(
            $handler->{dbh}, $handler->{data}{orphaned_items} );

        # load css & javascript for tab view
        $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
        $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];
    }

    $handler->process_template( undef );
    return OK;
}



1;

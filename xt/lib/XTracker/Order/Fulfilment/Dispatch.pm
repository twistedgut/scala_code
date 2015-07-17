package XTracker::Order::Fulfilment::Dispatch;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Distribution qw( get_dispatch_shipment_list );

use vars qw($r $operator_id);

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'Dispatch';
    $handler->{data}{content}       = 'ordertracker/fulfilment/dispatch.tt';

    # possible query string message
    $handler->{data}{error_msg}     = $handler->{request}->param('error_msg');

    # get list of shipments at the dispatch stage to display on screen
    # so long as you are not on a Hand Held device
    if ( $handler->{data}{is_manager} && !$handler->{data}{handheld} ) {
        $handler->{data}{shipments}     = get_dispatch_shipment_list( $handler->{dbh} );

        # load css & javascript for tab view
        $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
        $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];
    }

    return $handler->process_template( undef );
}

1;

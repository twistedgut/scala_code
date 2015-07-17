package XTracker::Order::Fulfilment::Hold;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Distribution qw( get_shipment_hold_list );

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
    $handler->{data}{subsection}    = 'On Hold';
    $handler->{data}{content}       = 'ordertracker/fulfilment/hold.tt';
    $handler->{data}{shipments}     = get_shipment_hold_list( $handler->{schema} );

    # load css & javascript for tab view
    $handler->{data}{css}           = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}            = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    my ( $sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst )= localtime(time);
    $month++;
    $year = $year + 1900;

    if ( $day < 10 )   { $day   = "0" . $day; }
    if ( $month < 10 ) { $month = "0" . $month; }

    $handler->{data}{today}     = $year . $month . $day;

    return $handler->process_template( undef );
}

1;

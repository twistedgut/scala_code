package XTracker::Order::Finance::InvalidPayments;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Finance qw( get_invalid_payment_list );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    $handler->{data}{content}       = 'ordertracker/finance/invalidpayments.tt';
    $handler->{data}{section}       = 'Finance';
    $handler->{data}{subsection}    = 'Invalid Payments';
    $handler->{data}{payments}      = get_invalid_payment_list($handler->{schema});

    # load css & javascript for tab view
    $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];


    return $handler->process_template( undef );
}

1;

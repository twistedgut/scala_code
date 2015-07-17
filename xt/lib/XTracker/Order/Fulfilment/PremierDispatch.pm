package XTracker::Order::Fulfilment::PremierDispatch;

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
    $handler->{data}{subsection}    = 'Premier Dispatch';
    $handler->{data}{content}       = 'ordertracker/fulfilment/premier_dispatch.tt';

    # possible query string message
    $handler->{data}{error_msg}     = $handler->{request}->param('error_msg');

    return $handler->process_template( undef );
}

1;

package XTracker::Order::Functions::Order::OrderAccessLog;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Order qw( get_order_info get_order_access_log );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    $handler->{data}{subsubsection} = 'Order Access Log';
    $handler->{data}{template_type} = 'blank';
    $handler->{data}{content}       = 'ordertracker/shared/orderaccesslog.tt';

    $handler->{data}{order_id}     = $handler->{request}->param('order_id');

    # get order info if we have an order id
    if ( $handler->{data}{order_id} ) {
        $handler->{data}{order} = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
        $handler->{data}{log}   = get_order_access_log( $handler->{dbh}, $handler->{data}{order_id} );
    }

    $handler->process_template( undef );

    return OK;

}


1;

__END__

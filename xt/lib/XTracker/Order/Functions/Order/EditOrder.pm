package XTracker::Order::Functions::Order::EditOrder;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Order;

use XTracker::Utilities qw( parse_url );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Edit Order';
    $handler->{data}{content}       = 'ordertracker/shared/editorder.tt';
    $handler->{data}{short_url}     = $short_url;

    # get id of order we're working on and order data for display
    $handler->{data}{orders_id}         = $handler->{request}->param('orders_id');
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{orders_id} );

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "$short_url/OrderView?order_id=$handler->{data}{orders_id}" } );

    # set sales channel to display on page
    $handler->{data}{sales_channel} = $handler->{data}{order}{sales_channel};

    return $handler->process_template( undef );
}


1;

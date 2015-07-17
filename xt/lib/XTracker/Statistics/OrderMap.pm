package XTracker::Statistics::OrderMap;

use strict;
use warnings;

use XTracker::Handler;
use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Database::Order qw( get_orders_by_date );
use XTracker::Config::Local;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    my $sales_channel   = $handler->{param_of}{sales_channel} || "";

    $handler->{data}{subsubsection} = 'Interactive Order Map';
    $handler->{data}{template_type} = 'blank';
    $handler->{data}{content}       = 'shared/order_map.tt';
    $handler->{data}{body_onload}   = 'javascript:loadMap();';
    $handler->{data}{api_key}       = config_var('XTracker', 'google_api_key');
    $handler->{data}{sales_channel} = $sales_channel;

    $handler->{data}{orders}        = get_orders_by_date( $handler->{dbh}, $handler->{param_of}{date}, $sales_channel );

    ($handler->{data}{year}, $handler->{data}{month}, $handler->{data}{day}) = split /-/, $handler->{param_of}{date};

    $handler->process_template( undef );

    return OK;

}


1;

__END__

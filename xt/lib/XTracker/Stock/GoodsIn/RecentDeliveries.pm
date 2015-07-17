package XTracker::Stock::GoodsIn::RecentDeliveries;

use strict;
use warnings;

use XTracker::Handler;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    # number of weeks history to show - default to 2 weeks
    $handler->{data}{select_weeks}  = $handler->{param_of}{'select_weeks'} || 2;

    $handler->{data}{section}       = 'Goods In';
    $handler->{data}{subsection}    = 'Recent Deliveries';
    $handler->{data}{subsubsection} = 'Previous '.$handler->{data}{select_weeks}.' Weeks';
    $handler->{data}{content}       = 'goods_in/recent_deliveries.tt';

    $handler->{data}{current_date}  = $handler->schema->db_now;

    # get list of deliveries
    my $rs = $handler->{schema}->resultset('Public::Delivery')
        ->recent_deliveries( $handler->{data}{select_weeks} )
        ->search({},{rows=>200, order_by => { -asc => 'me.date'} })
        ->page($handler->{param_of}{page}||1);
    $handler->{data}{recent_deliveries} = $rs;
    $handler->{data}{pager} = $rs->pager;

    return $handler->process_template;
}

1;

package XTracker::Order::CustomerCare::OrderSearch::SearchForm;
use strict;
use warnings;
use DateTime;
use XTracker::Handler;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $dt = DateTime->now( time_zone => "local" );
    $handler->{data}{day}   = $dt->day;
    $handler->{data}{month} = $dt->month;
    $handler->{data}{year}  = $dt->year;

    $handler->{data}{section}       = 'Customer Care';
    $handler->{data}{subsection}    = 'Order Search';
    $handler->{data}{subsubsection} = '';

    $handler->{data}{channels}      = $handler->{schema}->resultset('Public::Channel')->search({is_enabled=>1});

    $handler->{data}{content}       = 'ordertracker/customercare/ordersearch/searchform.tt';

    # Disable sidenav
    $handler->{data}{fullwidthcontent} = 1;

    return $handler->process_template( undef );
}

1;

package XTracker::Stock::GoodsIn::Returns::SearchArrivals;

use strict;
use warnings;

use DateTime;

use XTracker::Error;
use XTracker::Handler;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $schema                    = $handler->{schema};
    $handler->{data}{view}        = $handler->{param_of}{view};
    $handler->{data}{content}     = 'stocktracker/goods_in/returns_in/search_arrivals.tt';
    $handler->{data}{section}     = 'Returns In';
    $handler->{data}{subsection}  = 'Search';

    $handler->{data}{js} = [ '/javascript/NapCalendar.js' ];

    push @{ $handler->{data}{sidenav}[0]{None} }, {
        title => 'New Arrival',
        url   => '/GoodsIn/ReturnsArrival/Delivery',
    };

    my $now       = $schema->db_now;
    my $last_week = $now->clone->subtract(days => 7)->truncate(to => 'day');

    my ( $start, $end );

    my $date_regexp = '^(\d{4})-(\d{2})-(\d{2})$';

    # Get dates from template or set the default search dates
    if ( defined $handler->{param_of}{start}
        and $handler->{param_of}{start} =~ m{$date_regexp} )
    {
        $start = DateTime->new( year => $1, month => $2, day => $3, );
    }
    else {
        $start = $last_week;
    }

    if ( defined $handler->{param_of}{end}
        and $handler->{param_of}{end} =~ m{$date_regexp} )
    {
        $end = DateTime->new( year => $1, month => $2, day => $3, );
    }
    else {
        $end = $now;
    }

    # Pass the search parameters to the handler
    $handler->{data}{start} = $start->dmy;
    $handler->{data}{end}   = $end->dmy;

    # Include the end date in the search
    $end->add( days => 1 )->truncate( to => 'day' );

    # Get the return deliveries and pass them to the handler
    $handler->{data}{return_delivery_rs}
        = $schema->resultset('Public::ReturnDelivery')->search_by_date( $start, $end );

    return $handler->process_template;
}

1;

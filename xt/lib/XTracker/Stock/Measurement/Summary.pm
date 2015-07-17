package XTracker::Stock::Measurement::Summary;

use strict;
use warnings;

use XTracker::Handler;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{section} = 'Stock Control';
    $handler->{data}{subsection}    = 'Measurement';
    $handler->{data}{content}       = 'stocktracker/measurement/summary.tt';

    return $handler->process_template( undef );
}

1;

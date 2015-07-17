package XTracker::Stock::Reservation::PreOrderExported;

use strict;
use warnings;

use XTracker::Logfile                   qw( xt_logger );
use XTracker::Config::Local qw( config_var );
use XTracker::Database::PreOrder qw( :utils );

use XTracker::Handler;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $interval = config_var( 'PreOrder', 'export_to_order_delay' ) || '1 hour';

    $handler->{data}{section}            = 'Reservation';
    $handler->{data}{subsection}         = 'Customer';
    $handler->{data}{subsubsection}      = 'Pre Order Exported';

    $handler->{data}{content}    = 'stocktracker/reservation/pre_order_exported.tt';

    $handler->{data}{pre_order_items} = get_pre_order_items_awaiting_orders(
        $handler->{schema},
        $interval
    );

    xt_logger->debug(scalar( $handler->{data}{pre_order_items} ) . " retrieved");

    return $handler->process_template;
}

1;

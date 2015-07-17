package XTracker::Stock::GoodsIn::Stock::DeliveryCancel;

use strict;
use warnings;
use Carp;

use XTracker::Handler;
use XTracker::Database::Delivery qw( get_cancelable_deliveries );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    # possible error msg from url
    $handler->{data}{error_msg} = $handler->{request}->param('error_msg') || '';

    $handler->{data}{section}    = 'Goods In';
    $handler->{data}{subsection} = 'Delivery Cancel';
    $handler->{data}{content}    = 'goods_in/stock/delivery_cancel.tt';

    # grab list of deliveries that meet the criteria for cancellation
    $handler->{data}{deliveries} = get_cancelable_deliveries( $handler->dbh );

    return $handler->process_template;
}

1;

package XTracker::Order::Finance::CreditHold::ViewBulkActionLog;

use strict;
use warnings;

use XTracker::Handler;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{content}       = 'ordertracker/finance/view_bulk_order_action_log.tt';
    $handler->{data}{section}       = 'Finance';
    $handler->{data}{subsection}    = 'Bulk Release Log';

    $handler->{data}{sidenav} = [{
        "None" => [{
            'title' => 'Back to Credit Hold',
            'url'   => '/Finance/CreditHold'
        }]
    }];

    $handler->{data}{logs}
        = $handler->{schema}->resultset('Public::BulkOrderActionLog')->get_logs_for_credithold_actions();

    return $handler->process_template();
}

1;

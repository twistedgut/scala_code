package XTracker::Order::Actions::UpdateOrder;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Utilities qw( parse_url );
use XTracker::Error;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get current section info
    my ($section, $subsection, $short_url) = parse_url($r);

    my $order_id            = $handler->{param_of}{order_id};
    my $email               = $handler->{param_of}{email};
    my $telephone           = $handler->{param_of}{telephone};
    my $mobile_telephone    = $handler->{param_of}{mobile_telephone};
    my $redirect            = $short_url.'/OrderView?order_id='.$order_id;

    eval {
        update_order_details( $handler->dbh, $order_id, $email, $telephone, $mobile_telephone );
    };
    if ($@) {
        xt_warn("An error occurred whilst updating the order:<br /> $@");
    }

    return $handler->redirect_to( $redirect );
}

1;


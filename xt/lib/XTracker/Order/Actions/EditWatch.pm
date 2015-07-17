package XTracker::Order::Actions::EditWatch;

use strict;
use warnings;
use XTracker::Handler;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Database::Customer qw( add_customer_flag delete_customer_flag );

use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :flag );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section info from url
    my ($section, $subsection, $short_url) = parse_url($r);

    # get data from query string
    my $action      = $handler->{request}->param('action');
    my $watch_type  = $handler->{request}->param('watch_type');
    my $customer_id = $handler->{request}->param('customer_id');
    my $order_id    = $handler->{request}->param('order_id');

    # return error if missing data
    if (!$action || !$watch_type || !$customer_id || !$order_id) {
        $handler->{data}{content}   = 'ordertracker/shared/orderview.tt';
        $handler->{data}{error}     = 'Unable to edit customer watch, required data missing.';
        return $handler->process_template;
    }

    eval {
        # id of flag we're adding - could be Finance or Customer Watch
        my $flag_id = 0;

        # determine flag type
        if ( $watch_type eq "Finance" ) {
            $flag_id = $FLAG__FINANCE_WATCH;
        }
        elsif ( $watch_type eq "Customer" ) {
            $flag_id = $FLAG__CUSTOMER_WATCH;
        }

        my $schema = $handler->schema;
        my $dbh = $schema->storage->dbh;
        my $guard = $schema->txn_scope_guard;
        # adding watch flag
        if ( $action eq "Add" ){
            add_customer_flag( $dbh, $customer_id, $flag_id );
        }
        # removing watch flag
        elsif ( $action eq "Remove" ) {
            delete_customer_flag( $dbh, $customer_id, $flag_id );
        }
        # no other valid actions - do nothing
        else {
        }
        $guard->commit();
    };

    if ($@) {
        $handler->{data}{content}   = 'ordertracker/shared/orderview.tt';
        $handler->{data}{error}     = $@;
        return $handler->process_template;
    }

    # send user back to order view
    return $handler->redirect_to( "$short_url/OrderView?order_id=$order_id" );

}

1;

package XTracker::Order::Actions::DeleteFraudHotlist;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Finance;
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $redirect    = '/Finance/FraudHotlist';

    eval {
        my $schema = $handler->schema;
        my $guard = $schema->txn_scope_guard;

        foreach my $form_key ( %{ $handler->{param_of} } ) {
            if ( $form_key =~ m/-/ ) {

                my ($action, $id) = split /-/, $form_key;

                if ( $action eq 'delete' ) {
                    delete_hotlist_value($schema->storage->dbh, $id);
                }
            }
        }
        $guard->commit();
    };

    if ($@) {
        xt_warn("An error occured whilst trying to delete entry from the Hotlist: <br />$@");
    }

    return $handler->redirect_to( $redirect );
}

1;


package XTracker::Order::Actions::SetPackingStation;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Utilities             qw( url_encode );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    # by default re-direct back to /Fulfilment/Packing
    my $redirect    = '/Fulfilment/Packing';

    if ( exists $handler->{param_of}{ps_name} ) {

        my $schema  = $handler->{schema};
        my $msg     = "";

        eval {
            $schema->txn_do( sub {
                my $op_pref = $schema->resultset('Public::OperatorPreference');

                my $rec = $op_pref->update_or_create( {
                                    operator_id         => $handler->operator_id,
                                    packing_station_name=> $handler->{param_of}{ps_name},
                            } );

                if ( !defined $rec ) {
                    $msg    = "Couldn't save Packing Station preference";
                    die $msg;
                }

                # clear the preferences in the session so they get picked up the next time there's a page request
                delete $handler->session->{op_prefs};
            } );
        };
        if ( my $err = $@ ) {
            # if error redirect back to the select packing page with error message
            xt_warn($msg ? $msg : $err);
            $redirect   .= '/SelectPackingStation';
        }
        else {
            # if success redirect back to /Fulfilment/Packing with appropriate success message
            xt_success( $handler->{param_of}{ps_name}
                        ? "Packing Station Selected"
                        : "Packing Station Cleared"
                    );
        }
    }

    return $handler->redirect_to( $redirect );
}

1;

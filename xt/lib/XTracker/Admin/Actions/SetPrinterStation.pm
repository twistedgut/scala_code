package XTracker::Admin::Actions::SetPrinterStation;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Utilities qw( url_encode );
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $section = $handler->{param_of}{section};
    my $subsection = $handler->{param_of}{subsection};

    # by default re-direct back to /Section/Subsection
    my $redirect    = "/$section/$subsection";

    if ( exists $handler->{param_of}{ps_name} ) {
        my $schema  = $handler->{schema};
        my $msg     = "";

        eval {
            $schema->txn_do( sub {
                my $op_pref = $schema->resultset('Public::OperatorPreference');
                my $rec = $op_pref->update_or_create( {
                                    operator_id                => $handler->operator_id,
                                    printer_station_name       => $handler->{param_of}{ps_name},
                            } );

                if ( !defined $rec ) {
                    $msg    = "Couldn't save Printer Station preference";
                    die $msg;
                }

                # clear the preferences in the session so they get picked up the next time there's a page request
                delete $handler->session->{op_prefs};
            } );
        };
        if ( my $err = $@ ) {
            # if error redirect back to the select printer page with error message
            $redirect   .= "/SelectPrinterStation";
            xt_warn( $msg ? $msg : $err );
        }
        else {
            # if success redirect back to /Section/Subsection with appropriate success message
            xt_success( $handler->{param_of}{ps_name}
                        ? "Printer Station Selected"
                        : "Printer Station Cleared"
                    );
        }
    }

    return $handler->redirect_to( $redirect );
}

1;

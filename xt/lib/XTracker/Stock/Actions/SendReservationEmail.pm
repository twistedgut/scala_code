package XTracker::Stock::Actions::SendReservationEmail;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::EmailFunctions;

use XTracker::Database::Reservation qw( :email );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    # form submitted
    if ( $handler->{param_of}{customer_id} && $handler->{param_of}{channel_id} ){
        eval {
            if ( !grep { /^inc-/ } keys %{ $handler->{param_of } } ) {
                die "No Reservations were selected to be Notified\n";
            }

            my $guard = $handler->schema->txn_scope_guard;
            _send_notification($handler);
            $guard->commit();

            xt_success('Customer notification successful.');
        };
        if ( my $err = $@ ) {
            xt_warn( 'An error occured whilst trying to send the notification email: ' . $err );
        }
    }
    return $handler->redirect_to( $handler->{param_of}{redirect_url} || '/StockControl/Reservation/Email?operator_id='.$handler->{param_of}{operator_id} );
}

sub _send_notification {
    my ($handler) = @_;

    my $schema  = $handler->schema;

    my $channel = $schema->resultset('Public::Channel')->find(
        $handler->{param_of}{channel_id}
    );
    $handler->{data}{channel}   = $channel;

    my $email_info  = build_reservation_notification_email( $schema->storage->dbh, $handler );

    # send email
    send_customer_email( {
        to          => $handler->{param_of}{to_email},
        from        => $handler->{param_of}{from_email},
        reply_to    => $handler->{param_of}{from_email},
        subject     => $email_info->{subject},
        content     => $email_info->{content},
        content_type => $email_info->{content_type},
    } );
    return;
}

1;

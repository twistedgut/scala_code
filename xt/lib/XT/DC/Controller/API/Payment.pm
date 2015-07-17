package XT::DC::Controller::API::Payment;
use NAP::policy qw( tt class );

BEGIN { extends 'NAP::Catalyst::Controller::REST'; }

__PACKAGE__->config( path => 'api/payment', );

=head1 NAME

XT::DC::Controller::API::RefundHistory - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use XTracker::Database::Utilities;
use XTracker::Logfile qw( xt_logger );
use DateTime;
use Date::Parse;

=head1 METHODS

/                       404
/<id>                   404
/invalid                404
/<id>/invalid           404
/invalid/invalid        404
/<id>/refund_history    200

Special Case (upstream missing data):
/<id>/refund_history    404

Special Case (upstream failure):
/<id>/refund_history    500

=cut

sub orders_payment : Chained('/') : PathPrefix : CaptureArgs(2) {
    my ( $self, $c, $type, $id ) = @_;

    if ( $c->check_access( 'Finance' => 'Active Invoices' ) ) {

        # If it's not a valid database ID, we want to return a 400: Bad Request
        if ( is_valid_database_id( $id ) ) {

            my $payment = $type eq 'order'
                ? $c->model('DB::Orders::Payment')->find( $id )
                : $type eq 'preorder'
                    ? $c->model('DB::Public::PreOrderPayment')->find( $id )
                    : undef;

            if ( $payment ) {

                $c->stash( payment => $payment );

            } else {

                xt_logger->warn( "No payment record found for ID: $id" );
                $self->status_not_found( $c, message => "No payment record found for ID: $id" );

            }

        } else {

            xt_logger->warn( "Not a valid ID: $id" );
            $self->status_not_found( $c, message => "Not a valid ID: $id" );

        }

    } else {

        $self->status_unauthorized( $c );
        $c->detach;

    }

}

sub refund_history : Chained('orders_payment') : PathPart('refund_history') : ActionClass('REST') : Args(0) { }

sub refund_history_GET {
    my ( $self, $c ) = @_;

    if ( my $payment = $c->stash->{payment} ) {

        my $history = $payment->psp_get_refund_history;

        if ( ref( $history ) eq 'ARRAY' ) {

            if ( scalar @$history ) {

                $self->status_ok( $c, entity => [
                    map  { delete $_->{_sortkey}; $_ }
                    sort { $b->{_sortkey} <=> $a->{_sortkey} }
                    map  { {
                        _sortkey        => str2time( $_->{dateRefunded} ),
                        success         => $_->{success} ? 'Yes' : 'No',
                        reason          => $_->{reason},
                        amountRefunded  => $_->{amountRefunded} / 100,
                        dateRefunded    => DateTime->from_epoch( epoch => str2time( $_->{dateRefunded} ) )->strftime('%F %T'),
                    } }
                    @$history
                ] );

            } else {

                xt_logger->warn( 'There is no refund history currently available' );
                $self->status_not_found( $c, message => 'There is no refund history currently available' );

            }

        } else {

            xt_logger->warn( 'Payment service did not provide the required data' );
            $self->status_not_found( $c, message => 'Payment service did not provide the required data' );

        }

    }

}

=encoding utf8

=head1 AUTHOR

Andrew Benson

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


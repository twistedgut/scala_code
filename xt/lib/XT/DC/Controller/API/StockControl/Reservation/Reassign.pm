package XT::DC::Controller::API::StockControl::Reservation::Reassign;
use NAP::policy 'class';

BEGIN { extends 'NAP::Catalyst::Controller::REST' }

=head1 NAME

XT::DC::Controller::API::StockControl::Reservation::Reassign

=head1 DESCRIPTION

RESTful Catalyst controller for the API endpoint:

    /API/StockControl/Reservation/Reassign

=cut

use XTracker::Database::Utilities;
use XTracker::Logfile qw( xt_logger );

=head1 ENDPOINTS

=head2 /API/StockControl/Reservation/Reassign

The endpoint is RESTful and only supports POST, it takes a payload with the keys
C<reservation_id> and C<new_operator_id>. Where C<reservation_id> is reservation
being updated and C<new_operator_id> is the requested new operator for the
reservation.

If a field is missing or invalid, a Bad Request will be returned identifying
the problem.

If any of the records identified by the fields are not found, a Bad Request
will be returned identifying the missing record.

If the current operator is not allowed to change the operator of the given
C<reservation_id>, a Bad Request will be returned with an appropriate message.

If the C<reservation_id> is not updated for any reason, a Bad Request will be
returned with a generic message, please see the C<update_operator> method in
L<XTracker::Schema::Result::Public::Reservation> for details of why it might
not have been updated.

If the update dies, a Bad Request will be returned with a generic message and
the details logged.

=cut

sub reassign
    :Path('/API/StockControl/Reservation/Reassign')
    :ActionClass('REST') {}

sub reassign_POST {
    my ( $self, $c ) = @_;

    if ( $c->check_access ) {

        try {

            return if
                $self->field_is_invalid( $c, 'reservation_id' ) ||
                $self->field_is_invalid( $c, 'new_operator_id' );

            return unless
                my $reservation = $self->record_exists( $c, 'Reservation', 'reservation_id' );

            return unless
                my $new_operator = $self->record_exists( $c, 'Operator', 'new_operator_id' );

            my $operator = $c->model('DB::Public::Operator')
                ->find( $c->session->{operator_id} );

            my ( $success, $error ) = $reservation->update_operator( $operator->id, $new_operator->id );

            if ( $success ) {

                $self->status_ok( $c,
                    entity => { status => 'SUCCESS' },
                );

            } else {

                my $update_error = sprintf( 'Failed to transfer reservation "%u" from operator "%s" to operator "%s", because %s',
                    $reservation->id,
                    $reservation->operator->name,
                    $new_operator->name,
                    $error );

                $self->status_bad_request( $c, message => $update_error );

            }

        } catch {

            xt_logger->error( "Failed to update reservation status: $_" );

            # Can't respond with an internal server error, as XT "helpfully"
            # replaces the JSON with a nice friendly HTML error page!
            return $self->status_bad_request( $c,
                message => 'There was a problem processing the request' );

        }

    } else {

        $self->status_unauthorized( $c );
        $c->detach;


    }

}

=head1 METHODS

=head2 field_is_invalid( $c, $key )

Returns TRUE if the given C<$key> either doesn't exist in C<$c>->request->data,
or the value is not a valid database id. Returns UNDEF otherwise.

=cut

sub field_is_invalid {
    my $self = shift;
    my ( $c, $key ) = @_;

    return $self->status_bad_request( $c, message => "Missing Key: $key" )
        unless exists $c->request->data->{ $key };

    return $self->status_bad_request( $c, message => "Invalid Key: $key" )
        unless is_valid_database_id( $c->request->data->{ $key } );

    return;

}

=head2 record_exists( $c, $type, $key )

Returns the L<DBIx::Class::ResultSet> for the given C<$type> and C<$key> in
C<$c>->request->data if it exists, otherwise returns UNDEF and sets the
response to a Bad Request.

The C<$type> field determines the final part of the ResultSet name, i.e.
"Reservation" would translate to "DB::Public::Reservation".

=cut

sub record_exists {
    my $self = shift;
    my ( $c, $type, $key ) = @_;

    my $id      = $c->request->data->{ $key };
    my $record  = $c->model( 'DB::Public::' . $type )->find( $id );

    if ( $record ) {
        return $record;
    } else {
        $self->status_bad_request( $c, message => qq{A record for $key "$id" does not exist} );
        return;
    }

}


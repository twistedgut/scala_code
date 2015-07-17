package NAP::Catalyst::Controller::REST;
use NAP::policy 'class';

BEGIN { extends 'Catalyst::Controller::REST' }

=head1 NAME

NAP::Catalyst::Controller::REST

=head1 DESCRIPTION

Extends L<Catalyst::Controller::REST> to allow customisation.

=head1 METHODS

=head2 status_unauthorized( $c, $entity )

Returns a "401 Unauthorized" response. You must pass in the C<$c> catalyst
context object.

    $self->status_unauthorized( $c );

You can also pass an optional C<$entity> which is the (serialized) content
that will be returned. It defaults to:

    { error => 'Access Denied' }

=cut

sub status_unauthorized {
    my ( $self, $c, $entity ) = @_;

    $entity //= { error => 'Access Denied' };
    return $self->custom_status( $c, 401 => $entity );

}

=head2 status_internal_server_error

Returns a "500 Internal Server Error" response. You must pass in the C<$c> catalyst
context object.

    $self->status_internal_server_error( $c );

You can also pass an optional C<$entity> which is the (serialized) content
that will be returned. It defaults to:

    { message => 'Internal Server Error' }

=cut

sub status_internal_server_error {
    my ( $self, $c, $entity ) = @_;

    $entity //= { message => 'Internal Server Error' };
    return $self->custom_status( $c, 500 => $entity );
}

=head2 custom_status( $c, $code, $entity )

Generate a custom status response for HTTP C<$code> with a serialised
C<$entity>. You must pass in the C<$c> catalyst context object.

    $self->custom_status( $c, 401 => { error => 'Some Error' } );

=cut

sub custom_status {
    my ( $self, $c, $code, $entity ) = @_;

    $c->response->status( $code );
    $self->_set_entity( $c, $entity );

    return 1;

}

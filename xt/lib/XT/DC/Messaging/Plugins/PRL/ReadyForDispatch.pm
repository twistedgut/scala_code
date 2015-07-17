package XT::DC::Messaging::Plugins::PRL::ReadyForDispatch;
use NAP::policy "tt", 'class';
use Data::Dumper;

=head1 NAME

XT::DC::Messaging::Plugins::PRL::ReadyForDispatch - Handle ready_for_dispatch from PRL

=head1 DESCRIPTION

Handle ready_for_dispatch from PRL

We only actually get this from Dematic (it goes on the Dematic PRL queue).

For now we ignore it because nothing needs to happen.  In future, it may be
used to indicate that all labels have been applied to the box and sealing is
complete, but this would only be if we started using automatic carton sealers.

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'ready_for_dispatch' }

=head2 handler

Receives the class name, context, and pre-validated payload. For this message,
we do nothing except log.

=cut

sub handler {
    my ( $self, $c, $message ) = @_;

    $c->log->debug('Received ' . $self->message_type . ' with: ' . Dumper( $message ) );

    return 1;
}

package XT::DC::Messaging::Plugins::PRL::PrepareResponse;

use NAP::policy 'tt', 'class';

=head1 NAME

XT::DC::Messaging::Consumer::Plugins::PRL::PrepareResponse - Handle prepare_response from PRL

=head1 DESCRIPTION

Handle prepare_response from PRL

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'prepare_response' }

=head2 handler

Receives the class name, context, and pre-validated payload.

=cut

sub handler {
    my ( $self, $c, $message ) = @_;

    # put logic to handle message here
    my $schema = $c->model('Schema');
    my $allocation_rs = $schema->resultset('Public::Allocation');
    my $allocation = $allocation_rs->find({ id => $message->{allocation_id} })
        or die "Couldn't find allocation matching id " .
               "[$message->{allocation_id}] for prl [". $message->{prl}."]";

    $allocation->mark_as_prepared;
    $allocation->maybe_send_deliver_from_prepare_response;

    return;
}


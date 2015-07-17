package XT::DC::Messaging::Plugins::PRL::DeliverResponse;

use NAP::policy 'tt', 'class';

use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

=head1 NAME

XT::DC::Messaging::Consumer::Plugins::PRL::DeliverResponse - Handle deliver_response from PRL

=head1 DESCRIPTION

Handle deliver_response from PRL

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'deliver_response' }

=head2 handler

Receives the class name, context, and pre-validated payload.

=cut

sub handler {
    my ( $self, $c, $message ) = @_;
    my $schema = $c->model('Schema');

    # DCA-3410 - might need to do more for this story

    my $allocation_id = $message->{allocation_id};
    my $allocation_row = $schema->resultset('Public::Allocation')->search({
        'me.id'  => $allocation_id,
        'prl.amq_identifier' => $message->{prl},
    },{
        join => 'prl',
    })->first or die "Couldn't find allocation matching id [$allocation_id] for prl [". $message->{prl}."]";

    $allocation_row->mark_as_delivered($message, $APPLICATION_OPERATOR_ID);

}


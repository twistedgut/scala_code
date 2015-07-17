package XT::DC::Messaging::Plugins::PRL::PickComplete;
use NAP::policy "tt", 'class';

use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

=head1 NAME

XT::DC::Messaging::Consumer::Plugins::PRL::PickComplete - Handle pick_complete from PRL

=head1 DESCRIPTION

Handle pick_complete from PRL

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'pick_complete' }

=head2 handler

Receives the class name, context, and pre-validated payload.

The pick_complete message does not contain any information on who
recorded the pick_complete, so we pass in xtracker's application
operator id.

=cut

sub handler {
    my ( $self, $c, $message ) = @_;
    my $schema = $c->model('Schema');

    # Retrieve the allocation
    my $allocation_id = $message->{'allocation_id'};
    my $allocation_obj = $schema->resultset('Public::Allocation')->search(
        { 'me.id' => $allocation_id },
        { prefetch => { allocation_items => 'shipment_item' } }
    )->first or die sprintf( "Can't find an allocation with id [%s]",
        $allocation_id );

    $schema->txn_do(sub {
        $allocation_obj->pick_complete($APPLICATION_OPERATOR_ID);
    });

    $allocation_obj->maybe_send_deliver_from_pick_complete;
}

1;

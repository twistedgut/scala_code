package XTracker::Script::PRL::ResendPick;
use NAP::policy qw/class tt/;
extends "XTracker::Script";
with(
    "XTracker::Script::Feature::Schema",
    "XTracker::Script::Feature::Verbose",
    "XTracker::Role::WithAMQMessageFactory",
);

has allocation_id => (
    is  => 'ro',
    isa => 'Int',
);


=head1 DESCRIPTION

Resend the pick message for an allocation_id.

IMPORTANT: this doesn't do any db updates, it just sends the pick message,
so only use it for allocations that XT already things it has picked.

=head1 METHODS

=head2 invoke() : 0

Main entry point for the script. It uses object state as parameters.

=cut

sub invoke {
    my $self = shift;

    $self->inform("Resending pick message...\n");
        $self->msg_factory->transform_and_send(
            'XT::DC::Messaging::Producer::PRL::Pick',
            { allocation_id => $self->allocation_id }
        );

    $self->inform("Sent.\n\n");
}



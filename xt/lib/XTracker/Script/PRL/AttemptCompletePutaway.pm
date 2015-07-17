package XTracker::Script::PRL::AttemptCompletePutaway;

use NAP::policy qw/class/;
extends "XTracker::Script";

with(
    "XTracker::Script::Feature::SingleInstance",
    "XTracker::Script::Feature::Schema",
    "XTracker::Script::Feature::Verbose",
    "XTracker::Role::WithAMQMessageFactory",
);

has group_id => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
);

has putaway_prep_group_row => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $group_id = $self->group_id;
        $self->schema->resultset('Public::PutawayPrepGroup')
            ->find_active_group({group_id => $group_id});
    }
);

=head1 METHODS

=head2 invoke() : 0

Main entry point for the script. It uses object state as parameters.

=cut

sub invoke {
    my $self = shift;

    unless ($self->putaway_prep_group_row) {
        $self->inform(
            sprintf "Did not find an active group %s\n", $self->group_id
        );
        return
    }

    $self->display_summary();

    my $location_row = $self->putaway_prep_group_row
        ->putaway_prep_containers->first->destination;

    $self->inform("Attempting to complete putaway...\n");
    $self->putaway_prep_group_row->attempt_complete_putaway({
        message_factory => $self->msg_factory,
        location_row    => $location_row,
    });

    $self->inform("Done.\n\n");
}

sub display_summary {
    my $self = shift;

    $self->inform(
        sprintf(
            "*** Summary ***

PGID: %s
putaway_prep_group_id: %s
in status: %s
",
            $self->putaway_prep_group_row->canonical_group_id,
            $self->putaway_prep_group_row->id,
            $self->putaway_prep_group_row->status->status,
        ),
    );

    return;
}


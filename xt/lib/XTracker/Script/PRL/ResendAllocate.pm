package XTracker::Script::PRL::ResendAllocate;
use NAP::policy qw/class tt/;
extends "XTracker::Script";
with(
    "XTracker::Script::Feature::SingleInstance",
    "XTracker::Script::Feature::Schema",
    "XTracker::Script::Feature::Verbose",
    "XTracker::Role::WithAMQMessageFactory",
);

use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;
use XTracker::Constants::FromDB qw/:shipment_status/;

has allocation_id => (
    is  => 'ro',
    isa => 'Int',
);

has allocation_row => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $allocation_id = $self->allocation_id;
        $self->schema->find( Allocation => $allocation_id )
            or die("Could not find Allocation ($allocation_id)\n")
    }
);

=head1 METHODS

=head2 invoke() : 0

Main entry point for the script. It uses object state as parameters.

=cut

sub invoke {
    my $self = shift;

    $self->display_summary();

    $self->inform("Resending allocate message...\n");
    $self->allocation_row->send_allocate_message(
        $self->msg_factory,
    );

    $self->inform("Sent.\n\n");
}

sub display_summary {
    my $self = shift;

    my $allocation_row = $self->allocation_row;
    $self->inform(
        sprintf(
            "*** Summary ***

Shipment: %s
    Shipment status: %s
--> Allocation: %s: %s - %s <--
",
            $allocation_row->shipment_id,
            $allocation_row->shipment->shipment_status->status,
            $allocation_row->id,
            $allocation_row->status->status,
            $allocation_row->prl->name,
        ),
    );
    $self->inform(
        join(
            "\n",
            map { "        " . $_->id . ": " . $_->status->status }
            $allocation_row->allocation_items,
        ) . "\n\n\n",
    );

    return;
}


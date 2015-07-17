package NAP::XT::Exception::Allocation::CannotMarkAsDelivered;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::Allocation::CannotMarkAsDelivered

=head1 DESCRIPTION

Thrown if an attempt is made to mark an allocation as delivered when it
is not in the correct status.

=head1 ATTRIBUTES

=head2 allocation

The unpickable Allocation

=cut
has 'allocation' => (
    is => 'ro',
    isa => 'XTracker::Schema::Result::Public::Allocation',
    required => 1,
);

sub _allocation_id {
    my ($self) = @_;
    return $self->allocation->id();
}

sub _allocation_status {
    my ($self) = @_;
    return $self->allocation->status->status();
}

has '+message' => (
    default => q/Allocation %{_allocation_id}s cannot be marked as Delivered - status has to be 'Delivering' but is %{_allocation_status}s/,
);

1;

package NAP::XT::Exception::Allocation::Unpickable;
use NAP::policy "tt", 'exception';

=head1 NAME

NAP::XT::Exception::Allocation::Unpickable

=head1 DESCRIPTION

Thrown if an attempt it made to pick an Allocation that is in an upickable state

=head1 ATTRIBUTES

=head2 alloction

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
    default => q/Allocation %{_allocation_id}s has to be 'Allocated' but is %{_allocation_status}s/,
);

1;

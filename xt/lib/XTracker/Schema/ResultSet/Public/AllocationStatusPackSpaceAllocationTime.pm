package XTracker::Schema::ResultSet::Public::AllocationStatusPackSpaceAllocationTime;
use parent 'DBIx::Class::ResultSet';
use Moose;
use MooseX::NonMoose;

=head1 METHODS

=head2 allocation_status_id__is_pack_space_allocated : $status_id__has_pack_space

Return hash ref (keys: allocation_status_id; values:
is_pack_space_allocated).

=cut

sub allocation_status_id__is_pack_space_allocated {
    my $self = shift;
    return {
        map { $_->allocation_status_id => $_->is_pack_space_allocated }
        $self->search()
    };
}

1;

package XT::Data::PRL::PackArea;
use NAP::policy "tt", "class";
with "XTracker::Role::WithSchema";
with "XTracker::Role::WithXTLogger";

=head1 NAME

XT::Data::PRL::PackArea - The Packing area as a whole

=cut

use List::Util qw/ max /;
use DBIx::Class::RowRestore;
use Guard;



=head1 ATTRIBUTES

=cut

has packing_total_capacity => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->schema->resultset("Public::Prl")
            ->sysconfig_parameter("packing_total_capacity");
    },
);

sub _pack_lane_rs { shift->schema->resultset("Public::PackLane") }
sub _container_rs { shift->schema->resultset("Public::Container") }



=head1 METHODS

=head2 induction_capacity : $induction_capacity_count

The current Induction Capacity, i.e. the number of Totes that can be
scanned onto the Conveyor (or walked over) to be packed.

Note I: this is delegated to a runtime_property and is read from the db
on each access. If set, it's updated to the value you set each time.

Note II: If there's a chance you really want to change the value
instead of setting it, consider using the decrement_induction_capacity
instead, to avoid race conditions.

=cut

sub induction_capacity_row {
    my $self = shift;
    my $runtime_property_rs = $self->schema->resultset("Public::RuntimeProperty");
    return $runtime_property_rs->find_by_name("induction_capacity");
}

sub induction_capacity {
    my ($self, $induction_capacity) = @_;
    my $induction_capacity_row = $self->induction_capacity_row();

    if(@_>1) {
        $induction_capacity_row->update({ value => $induction_capacity });
    }

    return $induction_capacity_row->value;
}

=head2 accepts_containers_for_induction : Bool

Whether any Containers may be inducted to the PackArea at this moment.

=cut

sub accepts_containers_for_induction {
    my $self = shift;
    return $self->induction_capacity > 0;
}



=head1 METHODS

=head2 decrement_induction_capacity() :

Decrement the current database row value for "induction_capacity" by
doing an in-place update (to avoid any race conditions with the
PickScheduler, which will set it to the new, authoritative value it
just calculated).

=cut

sub decrement_induction_capacity {
    my $self = shift;
    return $self->induction_capacity_row->update(
        { value => \q{ value::integer - 1 } }
    );
}

=head2 containers_at_packing_count() : $container_count

Count of totes known to be at packing (or expected to arrive there
shortly).

This is the higher of:

    * Container counts reported by the pack lane scanners
    * Containers on their way or at a pack lane

=cut

sub containers_at_packing_count {
    my $self = shift;
    return max(
        $self->_pack_lane_rs->container_count_sum(),
        $self->_container_rs->filter_has_allocated_pack_space->count(),
    )
}

=head2 allocated_pack_space_count() : $pack_space_count

Return the number of allocations that are pre-packing, but have
already allocated pack space.

=cut

sub allocated_pack_space_count {
    my $self = shift;
    $self->schema->resultset("Public::Allocation")
        ->filter_is_allocation_pack_space_allocated->count;
}

=head2 remaining_capacity() : $packing_remaining_capacity

Return the number of remaining pack spaces in the PackArea.

=cut

sub remaining_capacity {
    my $self = shift;
    my $packing_total_capacity = $self->packing_total_capacity;
    my $containers_at_packing_count = $self->containers_at_packing_count;
    my $allocated_pack_space_count = $self->allocated_pack_space_count;

    my $packing_remaining_capacity = $packing_total_capacity
        - $containers_at_packing_count
        - $allocated_pack_space_count;

    $self->xtlogger->info((
        "PackArea: packing_remaining_capacity=$packing_remaining_capacity (from packing_total_capacity=$packing_total_capacity, containers_at_packing_count=$containers_at_packing_count, allocated_pack_space_count=$allocated_pack_space_count)",
    ));

    return $packing_remaining_capacity;
}

=head2 get_capacity_guard() : $capacity_row_guard_object

Return a Guard object that will restore any changes to the induction
capacity database row when it goes out of scope.

=cut

sub get_capacity_guard {
    my $self = shift;

    my $capacity_row = $self->induction_capacity_row();

    my $row_restore = DBIx::Class::RowRestore->new();
    my $row_guard = guard { $row_restore->restore_rows };
    $row_restore->add_to_update($capacity_row);

    return $row_guard
}



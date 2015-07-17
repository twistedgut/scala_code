package XTracker::Pick::PrlCapacity;
use NAP::policy "tt", "class";
with "XTracker::Role::WithSchema";

=head1 NAME

XTracker::Pick::PrlCapacity

=head1 DESCRIPTION

Capacities which are specific to a PRL, e.g. picking_total_capacity,
picking_remaining_capacity, staging_remaining_capacity,
induction_remaining_capacity, etc.


=head2 Naming conventions

  * total -- a config value indicating the total capacity of something,
    e.g. the picking_total_capacity indicates how many picks the staff
    in the PRL can handle

  * remaining -- The total capacity minus some the current
    workload. This is initialized at the start of the Pick::Scheduler
    run.

  * current_remaining -- The same as the remaining capacity, but this
    one is being updated in real time as the Pick::Scheduler
    runs.

    This is the actual value we're comparing / checking against. At
    the end, it'll be written to the runtime_property table.


=head2 Examples

  * picking_remaining_capacity
  * current_picking_remaining_capacity
  * current_induction_remaining_capacity
  * staging_remaining_capacity


=head2 PRLs without certain capacities

If any capacity isn't valid for a PRL, it's set to undef, and any
attempt to increase or reduce it will be a no-op. E.g. the Full PRL
has a staging_remaining_capacity (because it has an Induction Point),
but the GOH one doesn't.


=head2 Initial values

All current_remaining capacities are initialized to their remaining
capacity, and then usually reduced as the Pick::Scheduler makes
Allocations go into Picking.

The exception is the induction_remaining_capacity, which always starts
at 0 and then is increased as staged Allocations soft-allocates pack
space.


=cut

use MooseX::Params::Validate qw/ pos_validated_list /;

use XT::Data::PRL::PackArea;



=head1 ATTRIBUTES

=cut

sub runtime_property_rs { shift->schema->resultset("Public::RuntimeProperty") }

has prl_row => (
    is       => "ro",
    required => 1,
);

has prl_allocation_in_picking_count => (
    is       => "ro",
    required => 1,
);

has prl_container_in_staging_count => (
    is       => "ro",
    required => 1,
);

# Picking

has picking_remaining_capacity => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->prl_row->remaining_capacity(
            "picking",
            $self->prl_allocation_in_picking_count,
        );
    },
);

has current_picking_remaining_capacity => (
    is      => "rw",
    lazy    => 1,
    default => sub { shift->picking_remaining_capacity() },
    traits  => [ "Counter" ],
    handles => { reduce_current_picking_remaining_capacity => "dec" },
);

# Staging
# = total staging
# - allocations in picking
# - containers of allocations in staged

has staging_remaining_capacity => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->prl_row->remaining_staging_capacity(
            $self->prl_allocation_in_picking_count,
            $self->prl_container_in_staging_count,
        );
    },
);

has current_staging_remaining_capacity => (
    is      => "rw",
    lazy    => 1,
    default => sub { shift->staging_remaining_capacity() },
);

sub reduce_current_staging_remaining_capacity {
    my $self = shift;
    my $capacity = $self->current_staging_remaining_capacity();
    defined( $capacity ) or return undef;
    return $self->current_staging_remaining_capacity(
        $capacity - 1,
    );
}

# Induction

=head2 current_induction_remaining_capacity

This is initialized to 0 and is increased as we encounter allocations
in status staging.

=cut

has current_induction_remaining_capacity => (
    is      => "rw",
    lazy    => 1,
    default => sub { shift->prl_row->has_induction_point ? 0 : undef },
);

sub increase_current_induction_remaining_capacity {
    my ($self, $count) = @_;
    my $capacity = $self->current_induction_remaining_capacity();
    defined( $capacity ) or return undef;
    return $self->current_induction_remaining_capacity(
        $capacity + $count,
    );
}

=head2 inducted_container_ids

Hashref with (keys: container ids; values: 1) of Containers that have
already been accounted for as having claimed induction capacity in
this run through the Pick::Scheduler->schedule_allocations.

A single Container can (need) only claim induction/packing capacity
once. The case where this is interesting is when there are many
single-item allocations in a single Container.

=cut

has inducted_container_ids => (
    is      => "ro",
    isa     => "HashRef",
    default => sub { +{} },
);


=head2 BUILD() :

Trigger lazy defaults.

=cut

sub BUILD {
    my $self = shift;
    $self->current_picking_remaining_capacity;
    $self->current_staging_remaining_capacity;
    $self->current_induction_remaining_capacity;
}

=head2 ensure_pick_capacities(Sub::Actions $pick_actions) : Bool $is_allowed_to_pick

Return false if there isn't enough capacity to pick an allocation
(e.g. picking, staging), else true.

If there are enough picking capacities, add the actions to reduce the
appropriate capacities to $pick_actions (these will only be executed
once all checks are made that the pick can be performed).

=cut

sub ensure_pick_capacities {
    my $self = shift;
    my ($pick_actions) = pos_validated_list( \@_,
        { isa => 'Sub::Actions' },
    );

    return 0 if ( $self->current_picking_remaining_capacity <= 0 );

    # If this PRL has a staging capacity...
    my $staging_capacity = $self->current_staging_remaining_capacity;
    if ( defined($staging_capacity) ) {
        # ...there must be some left
        return 0 if ( $staging_capacity <= 0 );

        $pick_actions->add(
            sub { $self->reduce_current_staging_remaining_capacity() },
        );
    }

    # Ok, we're good to pick

    $pick_actions->add(
        sub { $self->reduce_current_picking_remaining_capacity() },
    );

    return 1;
}

=head2 maybe_claim_induction_capacity($container_rows) : $claimed_continer_count | undef

It may be that this PRL does't have a staging area, in which case we
can't claim any induction capacity. In that case, return undef.

If there is a staging area, increase the
->current_induction_remaining_capacity by the Containers in
$container_rows which have not previously claimed induction
capacity. Return the number of newly claimed containers.

You should have checked there is _any_ free pack space at all before
calling this (it's okay for the containers to reduce the pack space to
below zero).

=cut

sub maybe_claim_induction_capacity {
    my ($self, $container_rows) = @_;
    return 0 unless defined( $self->current_induction_remaining_capacity() );

    my $newly_claimed_container_rows
        = $self->claim_induction_capacity_for_new_container_rows($container_rows);

    my $count = @$newly_claimed_container_rows or return 0;
    $self->increase_current_induction_remaining_capacity($count);

    return $count;
}


=head2 claim_induction_capacity_for_new_container_rows($container_rows) : $newly_claimed_container_rows

Register $container_rows to claim induction capacity, but only ones
that haven't been seen before (i.e. which haven't earlier counted
towards the current induction capacity).

Return the $newly_claimed_container_rows, i.e. the ones which haven't
been seen before.

=cut

sub claim_induction_capacity_for_new_container_rows {
    my ($self, $container_rows) = @_;
    my @newly_claimed_container_rows =
        grep { ! $self->inducted_container_ids->{ $_->id }++ }
        @$container_rows;
    return \@newly_claimed_container_rows;
}

=head2 set_runtime_properties() :

Save current remaining capacity values to the runtime_property table.

=cut

sub set_runtime_properties {
    my $self = shift;
    $self->set_property(
        picking => $self->current_picking_remaining_capacity,
    );
    $self->set_property(
        staging => $self->current_staging_remaining_capacity,
    );

    # DCA-3540: TODO: replace induction_capacity with
    # full_induction_remaining_capacity everywhere, and remove this
    # special case.
    # (there are other places to change as well, especially in
    # PackArea and the Induction screen)

    # There's currently only one for Full, so this will be that one
    $self->set_runtime_property(
        induction_capacity => $self->current_induction_remaining_capacity,
    );
}

=head2 property_name($name) : $complete_property_name

Return the complete property name
(e.g. "dcd_picking_remaining_capacity") for $name (e.g. "picking").

=cut

sub property_name {
    my ($self, $name) = @_;
    return join( "_",
        $self->prl_row->identifier_name, $name, "remaining_capacity",
    );
}

=head2 set_property($name, $value) : $value | undef

Save the runtime_property $name (e.g. "staging", "picking") to $value
in the runtime_property table.

$name is shorthand and will be expanded to the full PRL
specific name.

Don't save if $value is undef.

=cut

sub set_property {
    my ($self, $name, $value) = @_;
    return $self->set_runtime_property( $self->property_name($name), $value );
}

=head2 set_runtime_property($property_name, $value) : $value | undef

Save the runtime_property $property_name
(e.g. "dcd_picking_remaining_capacity) to $value in the
runtime_property table.

Don't save if $value is undef.

=cut

sub set_runtime_property {
    my ($self, $property_name, $value) = @_;

    defined($value) or return undef;
    $self->runtime_property_rs->set_property($property_name, $value);

    return $value;
}

=head2 property_as_string($name) : $property_string | undef

Return display string for the property $name (e.g. "picking"), or
undef if there is no useful value.

=cut

sub property_as_string {
    my ($self, $name) = @_;
    my $attribute_name = "current_${name}_remaining_capacity";
    my $value = $self->$attribute_name() // return undef;
    my $property_name = $self->property_name($name);
    return "$property_name ($value)";
}

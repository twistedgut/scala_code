package XTracker::Pick::Scheduler::TriggeredAllocation;
use NAP::policy "tt", "class";

use List::MoreUtils qw(
    any
);
use List::Util qw/all/;

=head1 NAME

XTracker::Pick::Scheduler::TriggeredAllocation

=head1 DESCRIPTION

This class is used to determine whether the Allocation is triggered by
another Allocation in the same Shipment and whether it's blocked from
picking because of that.


=head2 Triggering PRLs

If a Shipment has an Allocation in only one PRL, it's just selected as usual.

If there are many Allocations in a Shipment, the Allocation in one PRL
might be triggered by the Allocation in another PRL.

Triggering and triggering order is configured in the prl_trigger_order
table.

If that's the case, the Allocation is triggered when the triggering
Allocation has allocated Pack Space. Until then it's blocked.

=head3 Which PRL Allocations trigger other Allocations?

  * Full (not triggered, it's not triggered by anything)

  * DCD (not triggered, could be triggered by a Full, but it has no
    sibling Allocations in the Shipment)

  * Full -> DCD (DCD triggered by Full)

  * GOH -> DCD (DCD also triggered by GOH)

  * Full, GOH -> DCD (DCD triggered by GOH because GOH is before Full
    in the prl_trigger_order table)


=head2 What makes an Allocation blocked?

An Allocation is blocked from picking if

  * It has an Allocation in a triggering PRL
  * and that Allocation hasn't yet allocated pack space


=head2 When does an Allocation have allocated pack space?

  * Full - When it has been inducted at the Full Induction Point
  * GOH - When it has gone beyond the status allocating_pack_space
  * DCD - When it has going into Picking


=head2 Dev considerations

You'll need to instantiate a new TriggeredAllocation object for each
->allocation_row to.



=head1 SYNOPSIS

    my $allocations = XTracker::Pick::Scheduler::TriggeredAllocation->new({
        pick_scheduler  => $self,
        allocation_row  => $allocation_row,
        allocation_rows => $shipment_allocation_rows,
    });
    $allocations->is_blocked_by_triggering_allocation();


=cut

=head1 ATTRIBUTES

=head2 allocation_row

The Allocation row to process.

=cut

has allocation_row => (
    is       => "ro",
    required => 1,
);

=head2 allocation_rows

All Allocation rows for a Shipment, possibly including
->allocation_row.

=cut

has allocation_rows => (
    is       => "ro",
    isa      => "ArrayRef",
    required => 1,
);

has pick_scheduler => (
    is       => "ro",
    isa      => "XTracker::Pick::Scheduler",
    required => 1,
);


=head2 sibling_allocation_rows() : $allocation_rows

All ->allocation_rows that are siblings to ->allocation_row.

=cut

has sibling_allocation_rows => (
    is         => "ro",
    lazy_build => 1,
);

sub _build_sibling_allocation_rows {
    my $self = shift;
    my $allocation_id = $self->allocation_row->id;
    return [ grep { $_->id != $allocation_id } @{$self->allocation_rows} ];

}


=head2 sibling_prl_rows() : \@prl_rows

Array ref of (unique) prl rows for the sibling allocations to
->allocation_row, in the order by which they trigger other PRLs'
Allocations.

=cut

has sibling_prl_rows => (
    is         => "ro",
    lazy_build => 1,
);

sub _build_sibling_prl_rows {
    my $self = shift;

    my %sibling_prl_row =
        map { $_->prl_id => $_->prl }
        @{$self->sibling_allocation_rows()};
    my @unique_prl_rows = values %sibling_prl_row;

    my $pick_scheduler = $self->pick_scheduler;
    my @ordered_prl_rows =
        sort {
            $pick_scheduler->prl_ordinal($a->id)
                <=>
            $pick_scheduler->prl_ordinal($b->id)
        }
        @unique_prl_rows;

    return \@ordered_prl_rows;
}


=head2 triggering_prl_row() : $prl_row | undef

The PRL row responsible for triggering the pick of ->allocation, or
undef if ->allocation isn't triggered by another allocation.

=cut

has triggering_prl_row => (
    is         => "ro",
    lazy_build => 1,
);

sub _build_triggering_prl_row {
    my $self = shift;

    my $triggering_prl_id_prl_row
        = $self->allocation_row->prl->triggering_prl_id_prl_row;
    my @triggering_sibling_prl_rows =
        grep { $triggering_prl_id_prl_row->{ $_->id } }
        @{$self->sibling_prl_rows()};

    return $triggering_sibling_prl_rows[0] || undef;
}


=head2 triggering_prl_allocation_rows() : $allocation_rows | []

Allocation rows for the ->triggering_prl_row, or an empty arrayref if
there isn't one.

=cut

has triggering_prl_allocation_rows => (
    is         => "ro",
    lazy_build => 1,
);

sub _build_triggering_prl_allocation_rows {
    my $self = shift;

    my $triggering_prl_row = $self->triggering_prl_row()
        or return [];

    my $sibling_allocation_rows = $self->sibling_allocation_rows();
    return [
        grep { $_->prl_id == $triggering_prl_row->id } @$sibling_allocation_rows,
    ];
}

=head1 METHODS

=cut

=head2 is_blocked_by_triggering_allocation() : Bool

Return true if ->allocation_row is blocked for picking by any other
allocation in ->allocation_rows, else false.

=cut

sub is_blocked_by_triggering_allocation {
    my $self = shift;

    # If there is no triggering sibling PRL, then we're not blocked.
    my $triggering_prl_row = $self->triggering_prl_row()
        or return 0;

    # Find all sibling allocations in this PRL.
    # If there is no other allocation row, not blocked.
    my $triggering_prl_allocation_rows = $self->triggering_prl_allocation_rows();
    @$triggering_prl_allocation_rows or return 0;

    # If any of the Allocations in that PRL have pack space, we're not
    # blocked.
    return 0 if $self->is_pack_space_allocated(
        $triggering_prl_allocation_rows,
    );

    # But if we have a triggering allocation and it doesn't have
    # pack space, and it has items in a state that mean it will
    # trigger a pick later, then we are blocked.
    return 1 if any {$_->has_triggering_items} @$triggering_prl_allocation_rows;

    # If none of them had any items to pick, we're not blocked.
    return 0;
}

=head2 is_pack_space_allocated($triggering_prl_allocation_rows) : Bool

Return true if any of the Allocation rows in
$triggering_prl_allocation_rows has allocated pack space, else false.

=cut

sub is_pack_space_allocated {
    my ($self, $triggering_prl_allocation_rows) = @_;

    my $triggering_prl_row = $self->triggering_prl_row()
        or return 0;

    my $status_id__has_pack_space
        = $triggering_prl_row->allocation_status_id__is_pack_space_allocated;

    for my $allocation_row (@$triggering_prl_allocation_rows) {
        my $is_pack_space_allocated = $status_id__has_pack_space->{
            $allocation_row->status_id,
        };
        return 1 if ($is_pack_space_allocated);
    }

    return 0;
}

=head2 am_i_fast_with_all_slow_siblings_picked() : Bool

Indicate if current triggered allocation belong to Fast PRL and
all its peers from slow PRLs are ready to be packed (are inducted).

=cut

sub am_i_fast_with_all_slow_siblings_picked {
    my $self = shift;

    # Make sure current allocation belongs to fast PRL,
    # otherwise it does not make a sense.
    # (prl attribute is prefetched on allocation object: no DB calls)
    return 0 unless $self->allocation_row->prl->is_fast;

    # Make sure allocation is not alone withing its shipment
    return 0 unless @{$self->sibling_allocation_rows};

    my @allocations_from_slow_prls = grep
        { $_->prl->is_slow }
        @{$self->sibling_allocation_rows};

    # Make sure there are sibling allocations from slow PRLs
    return 0 unless @allocations_from_slow_prls;

    return all { $_->is_picked } @allocations_from_slow_prls;
}

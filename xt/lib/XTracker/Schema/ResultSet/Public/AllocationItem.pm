package XTracker::Schema::ResultSet::Public::AllocationItem;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use XTracker::Constants::FromDB qw(
    :allocation_item_status
    :allocation_status
);
use MooseX::Params::Validate qw/pos_validated_list/;

=head2 filter_active

Filter allocation items by those whose status isn't in an end state.

=cut

sub filter_active {
    my $self = shift;
    $self->search({
        'status.is_end_state' => 'false'
    }, {
        join => 'status'
    });
}

=head2 filter_picked() : $allocation_item_rs | @allocation_item_rows

Filter only items in status "picked".

=cut

sub filter_picked {
    my $self = shift;
    my $me = $self->current_source_alias;
    $self->search({ "$me.status_id" => $ALLOCATION_ITEM_STATUS__PICKED });
}

=head2 pickable_count

Return count of allocation items in this rs
which aren't picked, cancelled or short picked.
(assumes records are prefetched)

=cut

sub pickable_count {
    my $self = shift;
    my $pickable_statuses = [
        $ALLOCATION_ITEM_STATUS__REQUESTED,
        $ALLOCATION_ITEM_STATUS__ALLOCATED,
        $ALLOCATION_ITEM_STATUS__PICKING
    ];

    my $count = 0;
    foreach my $item ($self->all) {
        $count+= 1 if grep {
            $item->status_id == $_
        } @$pickable_statuses;
    }
    return $count;
}

=head2 distinct_container_ids

Returns a list of container ids excluding nulls.

=cut

sub distinct_container_ids {
    my $self = shift;
    my $me = $self->current_source_alias;
    return $self->search({"$me.picked_into" => { q{!=} => undef } })
         ->get_column("$me.picked_into")
         ->func('distinct');
}

=head2 filter_delivered() : $self

Filter out those items that belong to allocations other than Delivered.

And only those that were actually delivered.

=cut

sub filter_delivered {
    my $self = shift;

    my $me = $self->current_source_alias;

    $self->search({
        'allocation.status_id' => $ALLOCATION_STATUS__DELIVERED,
        delivery_order => {'!=' => undef},
    },{
        join     => 'allocation',
        order_by => {-asc => "$me.delivery_order"},
    });
}

=head2 filter_missed_while_delivering() : $self

Filter current resultset to keep only records with allocation
in Delivered status but which are not been delivered - no
'delivery_order' values.

These records stand for SKU that should be checked on Problem rail.

=cut

sub filter_missed_while_delivering {
    my $self = shift;

    return $self->search({
        'allocation.status_id' => $ALLOCATION_STATUS__DELIVERED,
        delivery_order         => undef,
    },{
        join     => 'allocation',
    });
}

=head2 filter_non_integrated() : $self

Filter out integrated items.

=cut

sub filter_non_integrated {
    my $self = shift;

    $self->search({
        'integration_container_items.id' => undef,
    },{
        join => 'integration_container_items',
    });
}

=head2 filter_expected_on_problem_rail() : $self

Filter to items that haven't been delivered properly but could be on the
problem rail awaiting integration from there.

=cut

sub filter_expected_on_problem_rail {
    my $self = shift;

    return $self
        ->filter_missed_while_delivering
        ->filter_non_integrated;
}

=head2 distinct_containers() : @container_rows | $container_rs

Return resultset with distinct Continers these AllocatioItems are
picked into.

=cut

sub distinct_containers {
    my $self = shift;
    return $self
        ->search_related("shipment_item")
        ->search_related("container", undef, { distinct => 1 });
}

1;

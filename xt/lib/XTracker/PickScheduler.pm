package XTracker::PickScheduler;
use NAP::policy "tt", 'class';
with qw(
    XTracker::Role::WithSchema
    XTracker::Role::WithAMQMessageFactory
);

use List::Util qw/
    min
    max
/;
use DateTime;

use XT::Data::PRL::PackArea;
use XTracker::Config::Local 'config_var';
use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw/:allocation_status :shipment_item_status :prl/;
use vars qw/$PRL__DEMATIC $PRL__FULL/;
use XTracker::Database;
use XTracker::Logfile qw/xt_logger/;

=head1 NAME

XTracker::PickScheduler

=head1 DESCRIPTION

This class will send pick messages for allocations and update the induction
capacity.

=head1 SYNOPSIS

We will generally need to call just two methods outside of this class.

    use XTracker::PickScheduler;

    my $pick_scheduler = XTracker::PickScheduler->new;
    $pick_scheduler->pick_full_shipments;
    $pick_scheduler->set_induction_capacity_and_release_dms_only;

=head1 TODO

Set up logging infrastructure.


=head1 ATTRIBUTES

=head2 schema

Returns a DBIC schema object.

=head2 msg_factory

Returns an AMQ message factory object.

=head2 staging_area_size

Return the desired staging area size.

=head2 full_prl_pool_size

Return the Full PRL's desired pool size.

=head2 packing_pool_size

The total amount of containers that can be on the packlanes at once

=cut

# DCA-3589: old pick scheduler, remove
for my $name ( qw/staging_area_size full_prl_pool_size packing_pool_size/ ) {
    has $name => (
        is => 'rw',
        default => sub { shift->lookup_config_value($name) },
        lazy => 1,
    );
}

has pack_area => (
    is   => "ro",
    lazy => 1,
    default => sub {
        my $self = shift;
        XT::Data::PRL::PackArea->new({ schema => $self->schema });
    },
);



=head1 METHODS

=head2 lookup_config_value( $name )

Looks up PRL config values for the given name.

=cut

# DCA-3589: retire this when the new pick scheduler goes live, replace
# with other one in ResultSet::Prl. Also retire the old rows.
sub lookup_config_value {
    my ( $self, $name ) = @_;
    return $self->schema->resultset("SystemConfig::ParameterGroup")
        ->parameter("prl", $name);
}

=head2 staging_area_rs

Return a resultset for allocations with a status of I<Staged>.

=cut

has staging_area_rs => (
    is => 'rw',
    lazy_build => 1,
);

sub _build_staging_area_rs {
    my $self = shift;
    return $self->schema
        ->resultset('Public::Allocation')
        ->search_rs({
            "me.status_id" => $ALLOCATION_STATUS__STAGED,
        });
}

=head2 current_staging_area_size

Return the number of containers currently in the Staging Area.

=cut

sub current_staging_area_size {
    my $self = shift;
    my @container_ids_in_staging = $self
        ->staging_area_rs
        ->search_related('allocation_items')
        ->distinct_container_ids;
    return scalar @container_ids_in_staging;
}

=head2 current_full_allocations_being_picked_rs

Return a resultset of allocations being picked in the Full PRL.

=cut

has current_full_allocations_being_picked_rs => (
    is         => 'rw',
    lazy_build => 1,
);

sub _build_current_full_allocations_being_picked_rs {
    return shift->schema
        ->resultset('Public::Allocation')
        ->search_rs({
            status_id => $ALLOCATION_STATUS__PICKING,
            prl_id    => $PRL__FULL,
        });
}

=head2 selection_list_rs

Return a resultset for shipments that are ready to be selected.

=cut

has selection_list_rs => (
    is         => 'rw',
    lazy_build => 1,
);

sub _build_selection_list_rs {
    return shift->schema->resultset('Public::Shipment')->get_selection_list({
        exclude_held_for_nominated_selection=> 1,
        exclude_non_prioritised_samples     => 1,
        prioritise_samples                  => 1,
    })->search_rs;
}

=head2 debug

Create your PickScheduler object by passing with a subref for printing (e.g.
C<sub { note @_; }>) as a value for debug if you want to debug output for this
module.

=cut

has 'debug' => (
    is      => 'rw',
    default => sub{ sub{} },
);

=head2 staging_area_capacity

Return the capacity for the staging area.

=cut

sub staging_area_capacity {
    my $self = shift;

    my $staging_area_capacity = $self->staging_area_size
        - $self->current_staging_area_size
        - $self->number_of_full_allocations_being_picked;

    $self->set_runtime_property ('containers_in_staging', $self->current_staging_area_size);
    $self->set_runtime_property ('allocations_in_picking_full', $self->number_of_full_allocations_being_picked);
    $self->set_runtime_property ('staging_capacity', $staging_area_capacity);

    return $staging_area_capacity;
}

=head2 full_prl_capacity

Return the capacity for the Full PRL.

=cut

sub full_prl_capacity {
    my $self = shift;
    return $self->full_prl_pool_size
        - $self->number_of_full_allocations_being_picked;
}

=head2 number_of_full_allocations_being_picked

Return the number of allocations currently being picked

=cut

sub number_of_full_allocations_being_picked {
    my $self = shift;
    return $self->current_full_allocations_being_picked_rs->count;
}

=head2 pick_full_shipments() : @picked_allocations

Pick shipments from the Full PRL.

=cut

# DCA-3589: old pick scheduler, remove
sub pick_full_shipments {
    my $self = shift;

    # The lesser of those two
    my $number_of_orders_to_release
        = min $self->staging_area_capacity, $self->full_prl_capacity;

    xt_logger('PickScheduling')->debug("In pick_full_shipments, number of orders to release is $number_of_orders_to_release (staging_area_capacity = ".$self->staging_area_capacity." full_prl_capacity = ".$self->full_prl_capacity.")");

    # Stop here unless we have some capacity
    return if $number_of_orders_to_release <= 0;

    # A cursor to shipments with a Full PRL allocation, ordered by priority, and
    # at most the number of orders we want to release

    my @allocations = $self->selection_list_rs->search_related('allocations',
        {
            'allocations.status_id' => $ALLOCATION_STATUS__ALLOCATED,
            'prl.name' => 'Full'
        },{
            rows => $number_of_orders_to_release,
            join => 'prl',
        },
    )->all;

    # For each outstanding order
    for my $allocation (@allocations) {
        # We don't log the exception, as it logs itself
        try {
            $allocation->pick( $self->msg_factory, $APPLICATION_OPERATOR_ID );
        } catch {
            xt_logger()->error(sprintf('Failed to pick allocation %s: %s',
                $allocation->id(), $_));
        };
    }

    return @allocations;
}

=head2 picked_allocation_item_rs

Return a resultset of allocation items that have a status of B<Picked> and a
shipment item status of B<Picked>.

=cut

has picked_allocation_item_rs => (
    is => 'rw',
    isa => 'XTracker::Schema::ResultSet::Public::AllocationItem',
    lazy_build => 1,
);

# We can't easily determine what the latest allocation item is if we have
# multiple allocation items against one shipment item. So we have a bug here
# where this resultset can be a little bigger than the actual number of items
# that are picked. One way to fix this is to remove the container from the
# allocation item once it's been packed, and only include the number of items
# here that are in a container.
sub _build_picked_allocation_item_rs {
    shift->schema
         ->resultset('Public::ShipmentItem')
         ->search({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED})
         ->search_related_rs('allocation_items',
            { 'allocation.status_id' => [
                $ALLOCATION_STATUS__PICKING,
                $ALLOCATION_STATUS__PICKED,
            ] },
           { join => 'allocation' });
}

=head2 dms_allocations_in_picking_rs

Return a resultset of allocations that have a status of B<Picking> and are in
the DMS PRL.

=cut

# DCA-3589: old pick scheduler, remove
has dms_allocations_in_picking_rs => (
    is => 'rw',
    isa => 'XTracker::Schema::ResultSet::Public::Allocation',
    lazy_build => 1,
);

sub _build_dms_allocations_in_picking_rs {
    shift->schema->resultset('Public::Allocation')->search_rs({
        'prl.name' => 'Dematic',
        status_id => $ALLOCATION_STATUS__PICKING,
    },{
        join => 'prl',
    });
}

=head2 allocated_dms_only_rs

See docs for
L<XTracker::Schema::ResultSet::Public::Allocation::allocated_dms_only>

=cut

# DCA-3589: old pick scheduler, remove
has allocated_dms_only_rs => (
    is => 'rw',
    isa => 'XTracker::Schema::ResultSet::Public::Allocation',
    lazy_build => 1,
);

sub _build_allocated_dms_only_rs {
    my $self = shift;
    $self->schema->resultset('Public::Allocation')->allocated_dms_only->search(
        undef,
    );
}

=head2 pack_lane_spare_places

Return the current number of spare places on the pack lane.

=cut

sub pack_lane_spare_places {
    my $self = shift;
    my $packlane_rs = $self->schema()->resultset('Public::PackLane');

    my $dms_in_picking          = $self->dms_allocations_in_picking_rs->count();
    my $containers_at_packing   = $packlane_rs->get_total_container_count();
    my $containers_en_route     = $packlane_rs->get_total_containers_en_route_count();

    my $pack_lane_spare_places  = $self->packing_pool_size()
                                - $dms_in_picking
                                - $containers_at_packing
                                - $containers_en_route;

    $self->set_runtime_property ('allocations_in_picking_dms', $dms_in_picking);
    $self->set_runtime_property ('totes_at_packing', $containers_at_packing + $containers_en_route);
    $self->set_runtime_property ('packing_capacity', $pack_lane_spare_places);

    xt_logger('PickScheduling')->debug(
        "Pack lane spare places = packing pool size:" . $self->packing_pool_size
        . " - dms allocations in picking:" . $dms_in_picking
        . " - containers at pack lanes:" . $containers_at_packing
        . " - containers en route to pack lanes:" . $containers_en_route
        . " = $pack_lane_spare_places"
    );

    return $pack_lane_spare_places;
}

=head2 sort_allocations

Sort the given allocations by is_prioritised, sla_cutoff and shipment_id.

=cut

sub sort_allocations {
    my ( $self, @allocations ) = @_;

    # We think shipments *should* always have their sla set by they
    # time they get here, but if for some reason they don't have one,
    # we'll put them at the top because they might be special.
    my $default_sla = DateTime->from_epoch(epoch => 0);

    return (sort {
        $b->shipment->is_prioritised <=> $a->shipment->is_prioritised
     || DateTime->compare($a->shipment->sla_cutoff//$default_sla,
            $b->shipment->sla_cutoff//$default_sla)
     || $a->shipment->id <=> $b->shipment->id
    } @allocations);

}

=head2 set_induction_capacity($capacity) : $capacity

Set the PackArea induction capacity to C<$capacity>.

=cut

sub set_induction_capacity {
    my ( $self, $capacity ) = @_;
    return $self->pack_area->induction_capacity( $capacity );
}

=head2 set_runtime_property($property, $value)

Set the runtime property value, if we find a matching one.

To be used just for logging/informational purposes (see DCA-2357) so
if we can't find a matching property we just do nothing rather than
throwing an error.

=cut

sub set_runtime_property {
    my ($self, $property_name, $value) = @_;
    my $runtime_property_row = $self->schema->resultset("Public::RuntimeProperty")
        ->find_by_name($property_name);
    return unless $runtime_property_row; # Now is not the time to complain if we can't find it

    $runtime_property_row->update({
        value => $value
    });
}

=head2 set_induction_capacity_and_release_dms_only()

Release DMS allocations to the pack lane and set the induction capacity. The
induction capacity can then be read by another as-yet-unwritten process
(induction manager?) to make a decision as to how many containers can be
induced onto the pack lanes. While this method works out the induction capacity
it also sends pick messages to the DMS (if we have more 'quickpick' PRLs this
will have to be generalised to include all of them).

=cut

# TODO: When we revisit this code (and we will), think about splitting this
# into a wrapper that makes the call to another method that returns two items
# of data (a value to set the induction capacity to and a list of ids to send
# pick messages for), and then do the updates/sending messages in the wrapper.

# DCA-3589: old pick scheduler, remove
sub set_induction_capacity_and_release_dms_only {
    my $self = shift;

    # Firstly, how many spare places do we have on the pack lane?
    my $pack_lane_spare_places = $self->pack_lane_spare_places;

    # Give up if we have no spaces
    if ( $pack_lane_spare_places <= 0 ) {
        xt_logger('PickScheduling')->debug("No spare pack lane places");
        $self->set_induction_capacity(0);
        return;
    }

    my @allocations_to_pick = $self->_get_allocations_to_pick();

    xt_logger('PickScheduling')->debug("Pack lane spare places = ".$self->pack_lane_spare_places.", ordered allocations to consider: ".join(', ', map {$_->id} @allocations_to_pick));

    my $total_containers_used = 0;

    my %seen_container;
    # At the end of this loop, this number needs to be the number of Full PRL
    # allocations from the staging area that we want to induct
    my $induction_capacity = 0;

    # NOTE: We're deliberately not putting the following loop and the set
    # induction capacity in a transaction because we're potentially sending
    # messages within each iteration of the loop and we don't have the
    # buffer-and-send-at-the-end-of-transaction code yet. Also we need to think
    # about if the over-engineering actually gives us any benefit.
    for my $allocation ( @allocations_to_pick ) {
        # Distinct containers in this allocation without the DMS ones (i.e.
        # excluding those without a container)
        my @allocation_containers = $allocation->distinct_container_ids;
        my $new_container_count = grep { !$seen_container{$_}++ } @allocation_containers;

        # If the shipment is Full PRL-based, we reserve a place for it at induction
        if ( $allocation->is_staged ) { # Comes from staging area
            # Increase the induction capacity by the number of containers in
            # this allocation
            $induction_capacity += $new_container_count;
            # if we have a DMS allocation that's associated with this shipment,
            # once we bring the Full PRL container on the pack lane we will
            # also need to save at least one more space to pick the DMS part.
            # SO: If we have a DMS related allocation, we increase container
            # count. The actual picking is done by another process
            if ( $allocation->shipment->allocations->dms->pre_picking->count ) {
                # Assume one container per allocation
                $new_container_count++;
            }
            xt_logger('PickScheduling')->debug("Allocation ".$allocation->id." is staged, induction capacity is now $induction_capacity and new_container_count is $new_container_count (in addition to containers already used $total_containers_used)");
        }
        # If the shipment is DMS only, we pick it
        else {
            # As we ignored DMS containers before we need to increase new container count
            xt_logger('PickScheduling')->debug("Allocation ".$allocation->id." is dematic, new_container_count is now $new_container_count");
            try {
                $allocation->pick( $self->msg_factory, $APPLICATION_OPERATOR_ID );
                $new_container_count++;
            } catch {
                xt_logger()->error(sprintf('Failed to pick allocation %s: %s',
                    $allocation->id(), $_));
            };
        }
        $total_containers_used += $new_container_count;
        xt_logger('PickScheduling')->debug("total_containers_used = ".$total_containers_used.", pack_lane_spare_places = ".$pack_lane_spare_places);
        last if $total_containers_used >= $pack_lane_spare_places;
    }
    # Save induction capacity somewhere so another process can tell users
    # to pick items off the staging area
    xt_logger('PickScheduling')->debug("Final induction capacity is $induction_capacity");
    $self->set_induction_capacity($induction_capacity);
    return;
}

# DCA-3589: old pick scheduler, remove
sub _get_allocations_to_pick {
    my ($self) = @_;

    # Allocated allocations in DMS that don't have an 'active' allocation in
    # the Full PRL and ones with shipments that passed their earliest selection date.
    my $dms_only_rs = $self
        ->allocated_dms_only_rs
        ->filter_not_on_hold
        ->exclude_held_for_nominated_selection;

    # Picked PRL allocations
    my $staging_area_rs = $self->staging_area_rs();

    my $all_allocations_rs = $dms_only_rs->union($staging_area_rs);

    my $sorted_but_unfiltered_allocation_rs =
        $all_allocations_rs->search_related('shipment')->sort_for_selection->search_related('allocations');

    my $me = $sorted_but_unfiltered_allocation_rs->current_source_alias();

    return $sorted_but_unfiltered_allocation_rs->search({
        "${me}.id" => { -in => $all_allocations_rs->get_column('id')->as_query() },
    });
}

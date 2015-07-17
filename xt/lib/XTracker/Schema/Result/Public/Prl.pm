use utf8;
package XTracker::Schema::Result::Public::Prl;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.prl");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "display_name",
  { data_type => "text", is_nullable => 0 },
  "is_active",
  { data_type => "boolean", is_nullable => 0 },
  "location_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "prl_speed_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "prl_pick_trigger_method_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "prl_pack_space_allocation_time_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "prl_pack_space_unit_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "has_staging_area",
  { data_type => "boolean", is_nullable => 0 },
  "has_container_transfer",
  { data_type => "boolean", is_nullable => 0 },
  "has_induction_point",
  { data_type => "boolean", is_nullable => 0 },
  "has_local_collection_point",
  { data_type => "boolean", is_nullable => 0 },
  "has_conveyor_to_packing",
  { data_type => "boolean", is_nullable => 0 },
  "amq_queue",
  { data_type => "text", is_nullable => 1 },
  "amq_identifier",
  { data_type => "text", is_nullable => 1 },
  "identifier_name",
  { data_type => "text", is_nullable => 0 },
  "container_ready_requires_routing",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "max_allocation_items",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "allocations",
  "XTracker::Schema::Result::Public::Allocation",
  { "foreign.prl_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "integration_container_from_prl_ids",
  "XTracker::Schema::Result::Public::IntegrationContainer",
  { "foreign.from_prl_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "integration_container_prl_ids",
  "XTracker::Schema::Result::Public::IntegrationContainer",
  { "foreign.prl_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "location",
  "XTracker::Schema::Result::Public::Location",
  { id => "location_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "prl_delivery_destinations",
  "XTracker::Schema::Result::Public::PrlDeliveryDestination",
  { "foreign.prl_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "prl_integration_source_prl_ids",
  "XTracker::Schema::Result::Public::PrlIntegration",
  { "foreign.source_prl_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "prl_integration_target_prl_ids",
  "XTracker::Schema::Result::Public::PrlIntegration",
  { "foreign.target_prl_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "prl_pack_space_allocation_time",
  "XTracker::Schema::Result::Public::PrlPackSpaceAllocationTime",
  { id => "prl_pack_space_allocation_time_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "prl_pack_space_unit",
  "XTracker::Schema::Result::Public::PrlPackSpaceUnit",
  { id => "prl_pack_space_unit_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "prl_pick_trigger_method",
  "XTracker::Schema::Result::Public::PrlPickTriggerMethod",
  { id => "prl_pick_trigger_method_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "prl_pick_trigger_order_picks_triggered_by_ids",
  "XTracker::Schema::Result::Public::PrlPickTriggerOrder",
  { "foreign.picks_triggered_by_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "prl_pick_trigger_order_triggers_picks_in_ids",
  "XTracker::Schema::Result::Public::PrlPickTriggerOrder",
  { "foreign.triggers_picks_in_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "prl_speed",
  "XTracker::Schema::Result::Public::PrlSpeed",
  { id => "prl_speed_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sx4oVDV5WWONV1OPQTBUvg

use XTracker::Constants::FromDB qw/
    :allocation_status
    :prl
    :prl_pack_space_allocation_time
    :prl_speed
/;
use vars qw/
    $PRL__GOH
/;

use XTracker::Pick::PrlCapacity;



__PACKAGE__->many_to_many(
  "integrates_with",
  "prl_integration_source_prl_ids",
  "target_prl",
);

__PACKAGE__->many_to_many(
  "integrated_with",
  "prl_integration_target_prl_ids",
  "source_prl",
);

__PACKAGE__->many_to_many(
  "triggers_picks_in",
  "prl_pick_trigger_order_picks_triggered_by_ids",
  "triggers_picks_in",
);

__PACKAGE__->many_to_many(
  "picks_triggered_by",
  "prl_pick_trigger_order_triggers_picks_in_ids",
  "picks_triggered_by",
);

=head2 total_capacity($capacity_name) : $total_capacity

Return the ${capacity_name}_total_capacity sysconfig value for this
PRL. e.g. "picking", "staging".

=cut

sub total_capacity {
    my ($self, $capacity_name) = @_;
    my $total_capacity_name = join(
        "_",
        $self->identifier_name, $capacity_name, "total_capacity",
    );
    return $self->result_source->resultset->sysconfig_parameter(
        $total_capacity_name,
    );
}

=head2 remaining_capacity($capacity_name, $prl_count) : $remaining_capacity

Return the remaining capacity of type $capacity_name (e.g. "picking",
"staging") for this PRL (can be negative, which means "no free
capacity").

$prl_count is a hash ref (keys: ->prl_identifier; values: count to
deduct from the total for this type of capacity).

=cut

sub remaining_capacity {
    my ($self, $capacity_name, $prl_count) = @_;
    my $count = $prl_count->{ $self->identifier_name } // 0;
    return $self->total_capacity($capacity_name) - $count;
}

=head2 remaining_staging_capacity($prl_allocation_in_picking_count, $prl_container_in_staging_count) : $remaining_staging_capacity | undef

Return the remaining staging capacity for this PRL, given the
$prl_allocation_in_picking_count and $prl_container_in_staging_count,
or return undef if this PRL doesn't have a staging area.

$prl_allocation_in_picking_count and $prl_container_in_staging_count
are hashrefs with (keys: prl_identifier, values: count).

=cut

sub remaining_staging_capacity {
    my ($self, $prl_allocation_in_picking_count, $prl_container_in_staging_count) = @_;
    $self->has_staging_area or return undef;

    my $staging_remaining_capacity_in_picking = $self->remaining_capacity(
        "staging",
        $prl_allocation_in_picking_count,
    );

    my $container_in_staging_count
        = $prl_container_in_staging_count->{$self->identifier_name} // 0;

    return $staging_remaining_capacity_in_picking - $container_in_staging_count;
}

=head2 pick_complete_allocation_status : $allocation_status

Returns the status that an allocation for this PRL should be in following
processing of the pick_complete method

=cut

sub pick_complete_allocation_status {
    my $self = shift;

    my $status = $ALLOCATION_STATUS__PICKED;
    if ($self->has_staging_area) {
        $status = $ALLOCATION_STATUS__STAGED;
    }
    if ($self->prl_pack_space_allocation_time_id ==
        $PRL_PACK_SPACE_ALLOCATION_TIME__ALLOCATING_PACK_SPACE) {
        $status = $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE;
    }

    return $status;
}

sub allocates_pack_space_at_pick {
    my $self = shift;
    return !! (
        $self->prl_pack_space_allocation_time_id
            ==
        $PRL_PACK_SPACE_ALLOCATION_TIME__PICK
    );
}

=head2 as_prl_capacity($prl_allocation_in_picking_count, $prl_container_in_staging_count) : $prl_capacity

Return a new XTracker::Pick::PrlCapacity object with remaining
capacities (given the $prl_allocation_in_picking_count and
$prl_container_in_staging_count) for this PRL.

$prl_allocation_in_XXX_count is a hashref (keys: prl.identifier_name;
values: allocation_count) with allocation counts for all relevant
PRLs. This PRL should have an entry there. E.g.

    {
        full => 43,
        goh  => 230,
        dcd  => 3,
    }

=cut

sub as_prl_capacity {
    my ($self, $prl_allocation_in_picking_count, $prl_container_in_staging_count) = @_;
    XTracker::Pick::PrlCapacity->new({
        prl_row                         => $self,
        prl_allocation_in_picking_count => $prl_allocation_in_picking_count,
        prl_container_in_staging_count  => $prl_container_in_staging_count,
    });
}

=head2 triggering_prl_id() : $triggering_prl_id_hashref

Return hashref with (keys: prl ids, values: 1) for all _other_ prls
that trigger picks in this one.

=cut

# Tricky to prefetch, so caching this lookup in-process per PRL
my $prl_id_triggering_prl_id = {};
sub triggering_prl_id_prl_row {
    my $self = shift;
    return $prl_id_triggering_prl_id->{ $self->id } //= {
        map { $_->picks_triggered_by_id => $_->picks_triggered_by }
        $self->prl_pick_trigger_order_triggers_picks_in_ids
    };
}

=head2 allocation_status_id__is_pack_space_allocated : $status_id__has_pack_space

Return hash ref (keys: allocation_status_id; values:
is_pack_space_allocated) for this PRL.

=cut

sub allocation_status_id__is_pack_space_allocated {
    my $self    = shift;
    return $self
        ->prl_pack_space_allocation_time
        ->allocation_status_pack_space_allocation_times
        ->allocation_status_id__is_pack_space_allocated;
}

=head2 has_delivery_destinations : 0|1

Does this PRL have associated delivery destinations. Returns true or false.

=cut

sub has_delivery_destinations {
    my $self = shift;

    return !! $self->prl_delivery_destinations->count;
}

=head integrates_with_prl : 0|1

Given another PRL, work out whether or not this PRL integrates with the
other one.

=cut

sub integrates_with_prl {
    my ($self, $other_prl) = @_;

    my $is_source = $self->integrated_with->search({
        source_prl_id => $other_prl->id,
    })->count;
    my $is_target = $self->integrates_with->search({
        target_prl_id => $other_prl->id,
    })->count;

    return $is_source || $is_target;
}

=head2 default_integration_destination : $destination_name | undef

Return the destination for integration, or undef.

At the moment, the only PRL that supports integration is GOH.

=cut

sub default_integration_destination {
    my $self = shift;

    if ($self->id == $PRL__GOH) {
        return "GoodsOnHangerStations/goh_lane_integration";
    } else {
        return undef;
    }
}

=head2 is_slow : Bool

Current PRL is slow to deliver goods for packing.

=cut

sub is_slow {
    my $self = shift;

    return $self->prl_speed_id == $PRL_SPEED__SLOW;
}

=head2 is_fast : Bool

Current PRL is fast to deliver goods for packing.

=cut

sub is_fast {
    my $self = shift;

    return $self->prl_speed_id == $PRL_SPEED__FAST;
}

1;

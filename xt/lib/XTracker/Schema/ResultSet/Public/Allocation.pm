package XTracker::Schema::ResultSet::Public::Allocation;
# vim: ts=8 sts=4 et sw=4 sr sta
use parent 'DBIx::Class::ResultSet';
use Moose;
use MooseX::NonMoose;
with "XTracker::Schema::Role::ResultSet::GroupBy";

__PACKAGE__->load_components(qw{Helper::ResultSet::SetOperations});

use List::MoreUtils 'uniq';
use MooseX::Params::Validate qw/ pos_validated_list /;

use XT::Domain::PRLs;

use XTracker::Logfile           qw( xt_logger );
use XTracker::Config::Local     qw(
    config_var manifest_level manifest_countries get_ups_qrt
);
use XTracker::Constants::FromDB qw(
    :shipment_status
    :shipment_item_status
    :shipment_type
    :customer_category
    :prl
    :shipment_class
    :allocation_status
    :allocation_item_status
    :prl_pack_space_unit
);
use XTracker::Constants qw(
    $APPLICATION_OPERATOR_ID
);
use vars qw/$PRL__DEMATIC $PRL__FULL/;

=head1 NAME

XTracker::Schema::ResultSet::Public::Allocation

=head1 METHODS

=head2 pre_picking

Return a resultset with rows with a status of B<Requested> or B<Allocated>.

=cut

sub pre_picking {
    my $self = shift;
    my $me = $self->current_source_alias;
    return $self->search({ "${me}.status_id" => [
        $ALLOCATION_STATUS__REQUESTED, $ALLOCATION_STATUS__ALLOCATED
    ]});
}

=head2 excluding_id

Return a result excluding a single id. uses current_source_alias
so we can combine the resultset with prefetching correctly.

=cut

sub excluding_id {
    my ($self, $id) = @_;
    my $me = $self->current_source_alias;
    return $self->search({
        "$me.id" => { '!=' => $id },
    });
}

=head2 with_active_items

Return a resultset of allocations for rows with items not in an end state.

=cut

sub with_active_items {
    return shift->search(
        { 'status.is_end_state' => 0, },
        { join => { 'allocation_items' => 'status' }, distinct => 1 }
    );
}

=head2 allocated

Filter by B<Allocated> status.

=cut

sub allocated {
    my $self = shift;
    my $me = $self->current_source_alias;
    return $self->search({ "${me}.status_id" => $ALLOCATION_STATUS__ALLOCATED });
}

=head2 staged

Filter by B<Staged> status.

=cut

sub staged {
    my $self = shift;
    my $me = $self->current_source_alias;
    return $self->search({ "${me}.status_id" => $ALLOCATION_STATUS__STAGED });
}

=head2 exclude_allocation_by_id($allocation_id) : $allocation_rs | @allocation_rows

Return resultset that excludes the allocation id supplied

=cut

sub exclude_allocation_by_id {
    my ( $self, $allocation_id ) = @_;
    my $me = $self->current_source_alias;
    return $self->search(
        { "${me}.id" => {"!=" => $allocation_id} },
    );
}


=head2 ready_for_induction($container_is_in_commissioner) : $allocation_rs | @allocation_rows

Filter Allocations that are picked into a Container and are ready to
be inducted (this depends on whether the
$container_is_in_commissioner).

=cut

sub ready_for_induction {
    my ($self, $container_is_in_commissioner) = @_;
    my $allocation_status_id = $container_is_in_commissioner
        ? $ALLOCATION_STATUS__PICKED
        : $ALLOCATION_STATUS__STAGED;

    my $me = $self->current_source_alias;
    return $self->search({ "${me}.status_id" => $allocation_status_id });
}

=head2 filter_ready_for_integration() : $allocation_rs | @allocation_rows

Allocations in the correct status to be integrated.

=cut

sub filter_ready_for_integration {
    my $self = shift;
    my $me = $self->current_source_alias;
    return $self->search({
        "$me.status_id" => [
            $ALLOCATION_STATUS__PREPARING,
            $ALLOCATION_STATUS__PREPARED,
        ]
    });
}

=head2 filter_picked() : $allocation_rs | @allocation_rows

Allocations in status "picked".

=cut

sub filter_picked {
    my $self = shift;
    my $me = $self->current_source_alias;
    return $self->search({ "$me.status_id" => $ALLOCATION_STATUS__PICKED });
}

=head2 filter_picking() : $allocation_rs | @allocation_rows

Allocations in status "picking".

=cut

sub filter_picking {
    my $self = shift;
    my $me = $self->current_source_alias;
    return $self->search({ "$me.status_id" => $ALLOCATION_STATUS__PICKING });
}

=head2 filter_staged() : $allocation_rs | @allocation_rows

Allocations that are "staged", according to their Allocation status
and Shipment status.

=cut

sub filter_staged {
    my $self = shift;
    my $me = $self->current_source_alias;
    return $self
        ->filter_shipment_staged()
        ->search({ "$me.status_id" => $ALLOCATION_STATUS__STAGED });
}

=head2 filter_shipment_staged() : $allocation_rs | @allocation_rows

Allocations that are "staged", according to their Shipment status.

=cut

sub filter_shipment_staged {
    my $self = shift;

    my $shipment_rs = $self->result_source->schema->resultset("Public::Shipment");
    my $staged_status_ids = $shipment_rs->staged_status_ids();

    my $me = $self->current_source_alias;
    return $self->search(
        { "shipment.shipment_status_id" => { "in" => $staged_status_ids } },
        { join => "shipment" },
    );
}

=head2 dms

Return a resultset of allocations that are in DMS.

=cut

# DCA-3589: old pick scheduler, remove
sub dms {
    my $self = shift;
    return $self->search({
        prl_id => $PRL__DEMATIC,
    });
}

=head2 allocated_dms_only

Return a resultset with allocations with a status of B<Allocated> that don't
have any picked allocations belonging to the same shipment in the Full PRL.

=cut

# DCA-3589: old pick scheduler, remove
sub allocated_dms_only {
    my $self = shift;
    return $self->dms
                ->allocated
                ->with_active_items # this also includes 'picking' and 'requested',
                # but in practice this should never happen - we are actually using
                # this method to exclude 'short' and 'cancelled' items (and also
                # 'picked', but that shouldn't happen either)
                ->search({'me.id' => {
                    -not_in => [$self->pick_triggered_by_sibling_allocations]
                } });
}

=head2 exclude_held_for_nominated_selection: $allocation_resultset

Exclude allocations with shipments that did not reach their earliest selection date.

=cut

sub exclude_held_for_nominated_selection {
    my $self = shift;

    return $self->search({
        'shipment.nominated_earliest_selection_time' => [ undef, { q{<=} => \'NOW()' } ],
    },{
        join => { shipment => 'allocations' },
    });
}

=head2 filter_not_on_hold

Return a resultset of allocations whose shipment is ready for processing,
i.e. not on hold

=cut

sub filter_not_on_hold {
    my $self = shift;
    return $self->search({
        'shipment.shipment_status_id' => $SHIPMENT_STATUS__PROCESSING,
    },{
        join => { shipment => 'allocations' },
    });
}

=head2 filter_prls_without_staging_area() : $shipment_item_rs : @shipment_item_rows

Filter only Allocations in "fast" PRLs, without a Staging Area.

=cut

# DCA-3589: old pick scheduler, remove ?
sub filter_prls_without_staging_area {
    my $self = shift;
    return $self->search({
        "prl.has_staging_area" => 0,
    },{
        join => 'prl',
    });
}

=head2 filter_in_prl($prl_name) : $allocation_rs : @allocation_rows

Filter to return allocations in a named PRL

=cut

sub filter_in_prl {
    my $self = shift;
    my $prl_name = shift;

    return $self->search({
        'prl.name' =>  $prl_name,
    }, {
        join => 'prl',
    });
}

=head2 update_to_picked() :

Update the Allocations in the resultset to PICKED status.

=cut

sub update_to_picked {
    my ($self, $operator_id) = @_;
    $operator_id //= $APPLICATION_OPERATOR_ID;
    foreach my $allocation_row ($self->all) {
        $allocation_row->update_status($ALLOCATION_STATUS__PICKED, $operator_id);
        xt_logger('PickScheduling')->debug("updating allocation id ".$allocation_row->id." to picked");
    }
}

=head2 pick_not_triggered_by_sibling_allocations() : @ids

This method returns a list of allocation ids that have sibling allocations
(i.e.  allocations belonging to the same shipment) that would trigger their
pick.

As it stands any slow-pick PRLs that have a post-picking-staging-area
(e.g. Full PRL) trigger the picking of fast-pick PRL allocations
(e.g. DMS).

=cut

# DCA-3589: old pick scheduler, remove
sub pick_triggered_by_sibling_allocations {
    my $self = shift;

    # This is a difficult to query to write in one nice chainable DBIC search,
    # so splitting this up into two smaller queries that return a list of ids.
    # TODO: We could look at refactoring this to do an 'or' later if it's worth
    # it

    my @prls_with_staging_area = XT::Domain::PRLs::with_post_picking_staging_area;
    my $with_prls_with_staging_area = $self->with_siblings_in_prl_with_staging_area;
    xt_logger('PickScheduling')->trace("With any full prl sibling allocations: ".join(', ', sort {$a <=> $b} map { $_->get_column('id')->func('distinct') } $with_prls_with_staging_area)) if xt_logger('PickScheduling')->is_trace;

    # Look for allocations with siblings that haven't got as far as PICKED,
    # and have some up-to-picked items in (i.e. aren't entirely short or
    # cancelled), because these are the ones that we expect to go through
    # induction at some point in the future.
    my $triggered_by_sibling = $with_prls_with_staging_area
        ->with_siblings_in_status([
            $ALLOCATION_STATUS__REQUESTED,
            $ALLOCATION_STATUS__ALLOCATED,
            $ALLOCATION_STATUS__PICKING,
            $ALLOCATION_STATUS__STAGED,
        ])
        ->with_siblings_with_items_in_status([
            $ALLOCATION_ITEM_STATUS__REQUESTED,
            $ALLOCATION_ITEM_STATUS__ALLOCATED,
            $ALLOCATION_ITEM_STATUS__PICKING,
            $ALLOCATION_ITEM_STATUS__PICKED,
        ]);
    xt_logger('PickScheduling')->trace("With upcoming sibling allocations: ".join(', ', sort {$a <=> $b} map { $_->get_column('id')->func('distinct') } $triggered_by_sibling)) if xt_logger('PickScheduling')->is_trace;
    return uniq grep { $_ } map { $_->get_column('id')->func('distinct') }
        $triggered_by_sibling;
}

=head2 with_siblings_in_prl_with_staging_area( )

Return a resultset of allocations that have sibling allocations in any
prl that has a staging area.

=cut

# DCA-3589: old pick scheduler, remove
sub with_siblings_in_prl_with_staging_area {
    my ( $self, $prls ) = @_;
    return $self->_exclude_self_from_shipment_allocations->search(
        { 'prl.has_staging_area' => 1 },
        { join => { shipment => {'allocations' => 'prl'} } }
    );
}

=head2 with_siblings_in_status( $allocation_status_id )

Return a resultset of allocations that have siblings allocations with the given
C<$allocation_status_id>.

=cut

sub with_siblings_in_status {
    my ( $self, $status_id ) = @_;
    return $self->_exclude_self_from_shipment_allocations->search(
        { 'allocations.status_id' => $status_id },
        { join => { shipment => 'allocations' } }
    );
}

=head2 with_siblings_with_items_in_status( $allocation_item_status_id )

Return a resultset of allocations with sibling allocations that have allocation
items with the given C<$allocation_item_status_id>.

=cut

sub with_siblings_with_items_in_status {
    my ( $self, $status_id ) = @_;
    return $self->_exclude_self_from_shipment_allocations->search(
        { 'allocation_items.status_id' => $status_id },
        { join => { shipment => { allocations => 'allocation_items' } } }
    );
}

sub _exclude_self_from_shipment_allocations {
    my ( $self ) = @_;
    my $me = $self->current_source_alias;
    return $self->search(
        { 'allocations.id' => { q{!=} => \"${me}.id" } },
        { join => { shipment => 'allocations' } }
    );
}

=head2 picking_overview_window_day_count() : $cutoff_day_count

The number of days to list active Picks on the Picking Overview
page. If the active Picks for some reason would stay active beyond
this (shouldn't really happen), then they won't show up.

=cut

sub picking_overview_window_day_count {
    my $self = shift;
    my $day_count = config_var("PRL", "picking_overview_window_day_count");
    confess("Missing config key") unless (defined $day_count);
    return $day_count;
}

=head2 active_picking__shipment_id__rs() : $shipent_id_rs

Return resultset with shipment_id columns, for Shipments which have
started Picking some of its Allocations, but have still not finished
picking all of its Allocations.

=cut

sub active_picking__shipment_id__rs {
    my $self = shift;

    return $self
        ->has_started_picking__shipment_id__rs()
        ->intersect(
            $self->has_not_finished_picking__shipment_id__rs()
        )
        ->get_column("me.shipment_id");
}

=head2 has_started_picking__shipment_id__rs() : $shipment_id_rs

Return resultset with shipment_id columns, for Shipments which have
started Picking some of its Allocations.

Limit this to (currently) the last month, to avoid huge data volumes
in a year's time.

=cut

sub has_started_picking__shipment_id__rs {
    my $self = shift;
    my $cutoff_day_count = $self->picking_overview_window_day_count;
    return $self->search_rs(
        {
            # Includes PICKING, PICKED, STAGED
            pick_sent => {
                ">" => \"CURRENT_DATE - INTERVAL '$cutoff_day_count days'",
            },
        },
        {
            select => [ "me.shipment_id" ],
        },
    );
}

=head2 has_not_finished_picking__shipment_id__rs() : $shipment_id_rs

Return resultset with shipment_id columns, for Shipments which have
still not finished picking all of its Allocations.

Limit this to (currently) the last month, to avoid huge data volumes
in a year's time.

=cut

sub has_not_finished_picking__shipment_id__rs {
    my $self = shift;
    my $cutoff_day_count = $self->picking_overview_window_day_count;
    return $self->search_rs(
        {
            -or => [
                # for statuses earlier than PICKING
                { pick_sent => undef },
                # for PICKING
                {
                    pick_sent => {
                        ">" => \"CURRENT_DATE - INTERVAL '$cutoff_day_count days'",
                    },
                },
            ],
            "me.status_id" => {
                -not_in => [
                    $ALLOCATION_STATUS__PICKED,
                    $ALLOCATION_STATUS__STAGED,
                ],
            },
            # These indicate the allocation_item has finished picking,
            # i.e. there's nothing more to be done.
            "allocation_items.status_id" => {
                "-not_in" => [
                    $ALLOCATION_ITEM_STATUS__SHORT,
                    $ALLOCATION_ITEM_STATUS__CANCELLED,
                ],
            },
        },
        {
            join   => "allocation_items",
            select => [ "me.shipment_id" ],
        },
    );
}

=head2 filter_is_pack_space_allocated($pack_space_unit_id) : $allocation_rs | @allocation_rows

Allocations

 * for prls that count pack space in $pack_space_unit_id
 * and which are still being processed
 * and which are not yet completely picked (and therefore are already
   at packing)
 * and which have status which means they have pack space

=cut

sub filter_is_pack_space_allocated {
    my $self = shift;
    my ($pack_space_unit_id) = pos_validated_list(\@_,
        { isa => "Int" },
    );

    my $pack_space_allocation_times
        = "allocation_status_pack_space_allocation_times";
    my $me = $self->current_source_alias;
    $self
        ->filter_pack_space_unit( $pack_space_unit_id )
        ->filter_shipment_being_processed()
        ->filter_not_picked()
        ->search(
            {
                "$pack_space_allocation_times.allocation_status_id"
                    => { -ident => "$me.status_id" },
                "$pack_space_allocation_times.is_pack_space_allocated"
                    => 1,
            },
            {
                join => {
                    prl => {
                        prl_pack_space_allocation_time
                            => "$pack_space_allocation_times",
                    },
                },
            },
        );
}

=head2 filter_is_allocation_pack_space_allocated() : $allocation_rs

->filter_is_pack_space_allocated with "ALLOCATION".

=cut

sub filter_is_allocation_pack_space_allocated {
    my $self = shift;
    return $self->filter_is_pack_space_allocated(
        $PRL_PACK_SPACE_UNIT__ALLOCATION,
    );
}

=head2 filter_shipment_being_processed() : $allocation_rs

Filter Allocations which have a Shipment which is being processed
(PROCESSING or HOLD).

=cut

sub filter_shipment_being_processed {
    my $self = shift;
    $self->search(
        {
            "shipment.shipment_status_id" => [
                $SHIPMENT_STATUS__PROCESSING,
                $SHIPMENT_STATUS__HOLD,
            ],
        },
        { join => "shipment" },
    );
}

=head2 filter_not_picked() : $allocation_rs

Filter where status != PICKED.

=cut

sub filter_not_picked {
    my $self = shift;
    my $me = $self->current_source_alias;
    $self->search(
        { "$me.status_id" => { "!=" => $ALLOCATION_STATUS__PICKED } },
    );
}

=head2 filter_pack_space_unit($prl_pack_space_unit_id) : $allocation_rs

Filter Allocations which have the $prl_pack_space_unit_id.

=cut

sub filter_pack_space_unit {
    my ($self, $prl_pack_space_unit_id) = @_;
    $self->search(
        { "prl.prl_pack_space_unit_id" => $prl_pack_space_unit_id },
        { join                         => { prl => "prl_pack_space_unit" } },
    );
}

=head2 prl_allocation_count_rs() : $prl_count_rs

Return resultset with columns: prl, count, for the number of
Allocations per PRL.

=cut

sub prl_allocation_count_rs {
    my $self = shift;
    $self->search(
        undef,
        {
            join     => "prl",
            select   => [ "prl.identifier_name", \"count(*)" ],
            as       => [ "prl", "count" ],
            group_by => [ "prl.identifier_name" ],
        }
    );
}

=head2 prl_container_count_rs() : $prl_count_rs

Return resultset with columns: prl, count, for the number of
Containers per PRL.

This means Allocations' ShipmentItems which are picked into
Containers, i.e. after container_ready.

=cut

sub prl_container_count_rs {
    my $self = shift;
    $self->search(
        undef,
        {
            join => [
                "prl",
                { allocation_items => { shipment_item => "container" } },
            ],
            select   => [ "prl.identifier_name", \"count(distinct(container.id))" ],
            as       => [ "prl", "count" ],
            group_by => [ "prl.identifier_name" ],
        }
    );
}

=head2 allocations_picking_summary

Return an array describing allocations being picked with their status,
grouped by shipment.

=head3 Strategy

Find Shipments with
  any allocation that has started picking (or later)
    allocation in
      picking, picked, staged
  and
  any allocation that has not finished picking
    allocation_item not in
      short, picked

=cut

sub allocations_picking_summary {
    my ($self, $args) = @_;

    my $samples_filter;
    if ($args->{samples}) {
        $samples_filter = $SHIPMENT_CLASS__TRANSFER_SHIPMENT;
    }
    else {
        $samples_filter = { '!=' => $SHIPMENT_CLASS__TRANSFER_SHIPMENT };
    }

    # Main query to get the data we need
    my @allocation_rows = $self->search(
        {
            # Restrict to the shipments we found above
            'me.shipment_id' => {
                -in => $self->active_picking__shipment_id__rs->as_query,
            },

            # Fetch samples or not
            'shipment.shipment_class_id' => $samples_filter,

            # Don't list items which are no longer in play
            'allocation_items.status_id' => { '-not_in' => [
                $ALLOCATION_ITEM_STATUS__SHORT,
                $ALLOCATION_ITEM_STATUS__CANCELLED,
            ] },
        },
        {
            'join'     => [
                {
                    shipment => [
                        {
                            link_orders__shipments => {
                                orders => 'channel',
                            },
                        },
                        {
                            link_stock_transfer__shipments => {
                                stock_transfer => 'channel',
                            },
                        },
                    ],
                },
                'allocation_items',
            ],
            '+select' => [
                { "date_trunc" => "'second', (shipment.sla_cutoff - current_timestamp)" },
                { "max" => "allocation_items.picked_at" },
                { "count" => { "distinct" => "allocation_items.id" } },
                { "count" => {
                    "distinct" =>
                        "(CASE WHEN allocation_items.picked_at IS NOT NULL " .
                        "THEN allocation_items.id ELSE NULL END)" } },
                "shipment.id",
                "shipment.shipment_type_id",
                { "max" => "channel.id" },
                { "max" => "channel_2.id" },
            ],
            '+as' => [
                'sla_timer',
                'last_pick',
                'number_items',
                'number_picked',
                'shipment_id',
                'shipment_type_id',
                'order_channel_id',
                'transfer_channel_id',
            ],
            'group_by' => [
                'me.id',
                'me.shipment_id',
                'me.prl_id',
                'me.prl_delivery_destination_id',
                'me.status_id',
                'me.pick_sent',
                'shipment.id',
                'shipment.shipment_type_id',
                'shipment.sla_cutoff',
            ],
        },
    );

    my $schema = $self->result_source->schema;
    my $channel_id_display_name
        = $schema->resultset('Public::Channel')->id_display_name;
    my $shipments = {};
    my $item_grand_total = 0;
    for my $alloc (@allocation_rows) {
        my $shipment_id = $alloc->get_column('shipment_id');

        my $pick_sent = $alloc->pick_sent;
        my $number_items = $alloc->get_column('number_items');
        my $shipment = $shipments->{$shipment_id};
        if ($shipment) {
            $shipment->{pick_sent} = $pick_sent
                if !$shipment->{pick_sent} || $pick_sent && $pick_sent < $shipment->{pick_sent};
            $shipment->{number_items} += $number_items;
        }
        else {
            my $channel_id = $alloc->get_column('order_channel_id') ||
                             $alloc->get_column('transfer_channel_id');
            my $channel_name = $channel_id_display_name->{ $channel_id // "" };
            my $is_premier = $alloc->get_column('shipment_type_id') == $SHIPMENT_TYPE__PREMIER;
            my $sla_timer = $alloc->get_column('sla_timer');
            $shipment = {
                id           => $shipment_id,
                channel      => $channel_name,
                is_premier   => $is_premier,
                sla_timer    => $sla_timer,
                pick_sent    => $pick_sent,
                number_items => $number_items || 0,
                prls         => {},
                allocs       => [],
            };
            $shipments->{$shipment_id} = $shipment;
        }
        my $prl = $alloc->prl;
        $shipment->{prls}->{$prl->name} = 1 if $prl;
        my $last_pick_from_db = $alloc->get_column('last_pick');
        my $last_pick;
        $last_pick = DateTime::Format::Pg->parse_timestamptz($last_pick_from_db)
            if $last_pick_from_db;
        my $number_picked = $alloc->get_column('number_picked');
        my $scanned = $prl->has_staging_area && $alloc->is_picked;
        push @{$shipments->{$shipment_id}->{allocs}},
             {
                 id                    => $alloc->id,
                 pick_sent             => $pick_sent,
                 last_pick             => $last_pick,
                 prl                   => $prl->name,
                 number_items          => $number_items,
                 number_picked         => $number_picked,
                 scanned_onto_conveyor => $scanned,
             };
        $item_grand_total += $number_items;
    }

    # Convert PRL hashes to arrays
    for my $sid (keys %$shipments) {
       $shipments->{$sid}->{prls} = [ sort keys %{$shipments->{$sid}->{prls}} ];
    }

    return { shipments => $shipments, number_items => $item_grand_total };
}

1;

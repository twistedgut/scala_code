package Test::XTracker::Pick::Scheduler::GohActive;
use NAP::policy "tt", "test", "class";

# must be before "extends"
use Test::XTracker::RunCondition prl_phase => 2, pick_scheduler_version => 2;
BEGIN { extends "Test::XTracker::Pick::Scheduler" };

=head1 NAME

Test::XTracker::Pick::Scheduler - Unit tests for XTracker::Pick::Scheduler with GOH active

=head1 DESCRIPTION

Same as Pick::Scheduler, but for when the GOH prl is active. It should
be enough to run the tests in this once, in order to test the general
functionality for both.

One we've launched PRL rollout phase 2, unify these two files again.

=cut

use Carp;
use List::Util qw/ first /;

use Test::MockModule;

use XT::Domain::PRLs;
use XTracker::Constants::FromDB qw/
    :prl
    :allocation_status
/;
use vars qw/$PRL__DEMATIC $PRL__FULL $PRL__GOH /;
use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;

use XTracker::Pick::Scheduler;

use Test::XT::Fixture::Fulfilment::Shipment;
use Test::XTracker::Artifacts::RAVNI;

sub goh_prl_row  { shift->prl_row_for_id($PRL__GOH) }

sub full_dcd_goh_fixtures {
    my $self = shift;
    return $self->fixtures({ prl_ids => [ $PRL__FULL, $PRL__DEMATIC, $PRL__GOH ] });
}



### Basic attempt pick

sub test__process_shipment__attempt_pick__single_item__happy : Tests() {
    my $self = shift;

    note "Single GOH, Full, DCD, allocated";
    note "Test statuses, that picks are sent, capacities are calculated, and persisted";

    my $initial_picking_capacity = 1000; # Happy path test, plenty of capacity
    note "*** Setup";
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->setup_pick_scheduler_limited_to_fixtures(
        $self->full_dcd_goh_fixtures(),
        {
            packing_remaining_capacity    => 100, # Plenty of packing capacity
            dcd_picking_total_capacity    => $initial_picking_capacity,
            full_picking_total_capacity   => $initial_picking_capacity,
            goh_picking_total_capacity    => $initial_picking_capacity,
        },
    );

    note "** Setup sanity check";
    is(
        $pick_scheduler->shipments_to_schedule_rs->count,
        scalar @$shipment_rows,
        "Fixture shipments returned by query",
    );
    $self->test_allocation_status(
        "Sanity check",
        $allocation_rows,
        {
            Full    => [ $ALLOCATION_STATUS__ALLOCATED ],
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            GOH     => [ $ALLOCATION_STATUS__ALLOCATED ],
        },
    );

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new("xt_to_prls");

    my $reset_marker = 6345; # just any random value
    $self->reset_runtime_properties(
        [
            "packing_remaining_capacity",
            "induction_capacity",
            "full_picking_remaining_capacity",
            "full_staging_remaining_capacity",
            "dcd_picking_remaining_capacity",
            "goh_picking_remaining_capacity",
        ],
        $reset_marker,
    );

    note "*** Run";
    $pick_scheduler->schedule_allocations();


    note "*** Test";
    $self->test_allocation_status(
        "Test",
        $allocation_rows,
        {
            Full    => [ $ALLOCATION_STATUS__PICKING ],
            Dematic => [ $ALLOCATION_STATUS__PICKING ],
            GOH     => [ $ALLOCATION_STATUS__PICKING ],
        },
    );

    note "Test pick messages are sent";
    $xt_to_prl->expect_messages({
        messages => [map { +{ '@type' => 'pick' } } @$allocation_rows ],
    });

    note "Picking capacities should have decreased";
    for my $prl_row (@{$self->prl_rows}) {
        my $capacity = $pick_scheduler->capacity_for_prl($prl_row);
        is(
            $capacity->current_picking_remaining_capacity,
            $initial_picking_capacity - 1,
            "Picking capacity reduced by 1",
        );
    }

    $self->test_runtime_property(
        packing_remaining_capacity
            => $pick_scheduler->packing_remaining_capacity - 1,
    );

    my $full_capacity = $pick_scheduler->capacity_for_prl($self->full_prl_row);
    $self->test_runtime_property(
        induction_capacity => $full_capacity->current_induction_remaining_capacity,
    );
    $self->test_runtime_property(
        full_picking_remaining_capacity => $full_capacity->current_picking_remaining_capacity,
    );
    $self->test_runtime_property(
        full_staging_remaining_capacity => $full_capacity->current_staging_remaining_capacity,
    );

    my $dcd_capacity = $pick_scheduler->capacity_for_prl($self->dcd_prl_row);
    $self->test_runtime_property(
        dcd_picking_remaining_capacity => $dcd_capacity->current_picking_remaining_capacity,
    );

    my $goh_capacity = $pick_scheduler->capacity_for_prl($self->goh_prl_row);
    $self->test_runtime_property(
        goh_picking_remaining_capacity => $goh_capacity->current_picking_remaining_capacity,
    );

}

# GOH attempt pick, check picking capacity
sub test__process_shipment__attempt_pick__one_goh__no_picking_capacity : Tests() {
    my $self = shift;
    $self->test_schedule_allocations_with_fixtures({
        description                       => "Single GOH, no GOH picking capacity, no pick",
        mock_sysconfig_parameter          => {
            goh_picking_total_capacity    => 0, # no picking capacity in GOH
        },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 1, # One left in packing
        },
        sanity_check_allocation_status_id => { GOH => [ $ALLOCATION_STATUS__ALLOCATED ] },
        fixtures                          => { prl_ids => [ $PRL__GOH ] },
        test_description                  => "Still allocated (nothing picked)",
        allocation_status_ids             => { GOH => [ $ALLOCATION_STATUS__ALLOCATED ] },
        expected_packing_capacity         => 1, # Initial packing capacity
    });
}

sub test__process_shipment__attempt_pick__two_goh__only_one_picking_capacity : Tests() {
    my $self = shift;
    $self->test_schedule_allocations_with_fixtures({
        description              => "One capacity, two GOH shipments. One can be picked, the other not",
        mock_sysconfig_parameter => {
            goh_picking_total_capacity => 1, # Room for one allocation
        },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 100, # Plenty of pack space
        },
        sanity_check_allocation_status_id => {
            GOH => [
                $ALLOCATION_STATUS__ALLOCATED,
                $ALLOCATION_STATUS__ALLOCATED,
            ],
        },
        fixtures                 => { prl_ids => [ $PRL__GOH, $PRL__GOH ] },
        test_description         => "Only one picking",
        allocation_status_ids    => {
            GOH => bag(
                $ALLOCATION_STATUS__PICKING,
                $ALLOCATION_STATUS__ALLOCATED,
            ),
        },
        expected_packing_capacity         => 100, # Initial packing capacity
    });
}

sub test__process_shipment__attempt_pick__one_goh__no_packing_capacity : Tests() {
    my $self = shift;
    $self->test_schedule_allocations_with_fixtures({
        description                       => "Single GOH, no packing capacity, yes pick",
        mock_sysconfig_parameter          => {},
        pick_scheduler_args               => {
            packing_remaining_capacity    => 0, # No packing capacity
        },
        sanity_check_allocation_status_id => { GOH => [ $ALLOCATION_STATUS__ALLOCATED ] },
        fixtures                          => { prl_ids => [ $PRL__GOH ] },
        test_description                  => "Picked, GOH doesn't care about packing capacity",
        allocation_status_ids             => { GOH => [ $ALLOCATION_STATUS__PICKING ] },
        expected_packing_capacity         => 0, # Initial packing capacity
    });
}


### Attempt allocate pack space

sub test__process_shipment__attempt_allocate_pack_space__happy : Tests() {
    my $self = shift;
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       =>"One GOH in allocating_pack_space, with pack space: transition and reduce pack space",
        mock_sysconfig_parameter          => {},
        fixtures                          => { prl_ids => [ $PRL__GOH ] },
        fixture_map                       => sub { $_->with_allocating_pack_space_shipment },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 1, # Room for one more in packing
        },
        sanity_check_allocation_status_id => { GOH => [ $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE ] },
        test_description                  => "The pack space is allocating and we're went on to preparing",
        allocation_status_ids             => { GOH => [ $ALLOCATION_STATUS__PREPARING ] },
        expected_packing_capacity         => 0, # Allocated pack space
    });
}

sub test__process_shipment__attempt_allocate_pack_space__two_goh_one_allocates_pack_space : Tests() {
    my $self = shift;
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "Two GOH in allocating_pack_space, only pack space for one of them",
        mock_sysconfig_parameter          => {},
        fixtures                          => { prl_ids => [$PRL__GOH, $PRL__GOH] },
        fixture_map                       => sub { $_->with_allocating_pack_space_shipment },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 1, # Room for one more in packing
        },
        sanity_check_allocation_status_id => {
            GOH => [
                $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE,
                $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE,
            ],
        },
        test_description                  => "Pack space allocated for the firs one only",
        allocation_status_ids             => {
            GOH => bag(
                $ALLOCATION_STATUS__PREPARING,
                $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE,
            ),
        },
        expected_packing_capacity         => 0, # Allocated pack space
    });
}

# Full + GOH + DCD, inducting Full doesn't trigger DCD (GOH should do
# that)
sub test__process_shipment__attempt_pick_full_goh_dcd__picked_in_order__full_inducted__dcd_triggered_by_goh : Tests() {
    my $self = shift;

    note "Try to pick both allocations";
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
        $fixtures,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "Full+GOH+DCD allocated, Full, GOH gets picked",
        mock_sysconfig_parameter          => {
            full_picking_total_capacity => 100, # Plenty of picking capacity
            goh_picking_total_capacity  => 100, # Plenty of picking capacity
            dcd_picking_total_capacity  => 100, # Plenty of picking capacity
        },
        fixtures                          => {
            prl_name_pid_counts => { Dematic => 1, Full => 1, GOH => 1 },
        },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 100, # Plenty packing capacity
        },
        sanity_check_allocation_status_id => {
            Full    => [ $ALLOCATION_STATUS__ALLOCATED ],
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            GOH     => [ $ALLOCATION_STATUS__ALLOCATED ],
        },

        test_description                  => "Full allocation in picking, Dematic in allocated",
        allocation_status_ids             => {
            Full    => [ $ALLOCATION_STATUS__PICKING ],
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            GOH     => [ $ALLOCATION_STATUS__PICKING ],
        },
        expected_packing_capacity         => 100, # Same, still not at packing
        expected_picking_capacity         => { full => 99, dcd => 100, goh => 99 }, # Picking Full, GOH
    });
    my $fixture = $fixtures->[0];


    note "*** Setup: Get Full to staging";
    my $full_allocation_row =
        first { $_->prl_id == $PRL__FULL }
        @$allocation_rows;
    my $full_container_id = Test::XTracker::Data::Order->stage_allocation(
        $full_allocation_row,
    );

    note "Sanity check";
    $self->test_allocation_status(
        "Sanity check",
        $allocation_rows,
        {
            Full    => [ $ALLOCATION_STATUS__STAGED ],
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            GOH     => [ $ALLOCATION_STATUS__PICKING ],
        },
    );

    note "*** Run";
    $pick_scheduler->schedule_allocations();

    note "*** Test: DCD not triggered";
    $self->test_allocation_status(
        "Test staged",
        $allocation_rows,
        {
            Full    => [ $ALLOCATION_STATUS__STAGED ],
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            GOH     => [ $ALLOCATION_STATUS__PICKING ],
        },
    );



    note "*** Setup: Induct Full";
    my $full_container_row = $self->schema->find(Container => $full_container_id);
    $fixture->with_container_inducted($full_container_row);

    note "*** Test: DCD not triggered by Full inducted";
    $self->test_allocation_status(
        "Test inducted",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__PICKED ],
            GOH     => [ $ALLOCATION_STATUS__PICKING ],
        },
    );


    note "*** Setup: Run PS after Full inducted";
    $pick_scheduler->schedule_allocations();

    note "*** Test: DCD pick still not triggered";
    $self->test_allocation_status(
        "Test inducted",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__PICKED ],
            GOH     => [ $ALLOCATION_STATUS__PICKING ],
        },
    );


    note "*** Setup: Allocate pack space for GOH";
    note "** Pick GOH allocation";
    my $goh_allocation_row =
        first { $_->prl_id == $PRL__GOH }
        @$allocation_rows;
    my ($goh_container_id) = $fixture->allocation_pick_complete(
        $goh_allocation_row,
    );

    $self->test_allocation_status(
        "Test GOH pick_complete (now allocating pack space)",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__PICKED ],
            GOH     => [ $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE ],
        },
    );

    note "*** Setup: Run PS";
    $pick_scheduler->schedule_allocations();

    note "*** Test: DCD now triggered, picking";
    $self->test_allocation_status(
        "Test GOH allocated pack space and triggered DCD pick",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__PICKING ],
            Full    => [ $ALLOCATION_STATUS__PICKED ],
            GOH     => [ $ALLOCATION_STATUS__PREPARING ],
        },
    );

}

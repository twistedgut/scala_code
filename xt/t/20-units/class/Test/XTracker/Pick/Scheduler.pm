package Test::XTracker::Pick::Scheduler;
use NAP::policy "tt", "test", "class";
BEGIN { extends "NAP::Test::Class" };
use Test::XTracker::RunCondition prl_phase => "prl", pick_scheduler_version => 2, export => [qw( $prl_rollout_phase )];

=head1 NAME

Test::XTracker::Pick::Scheduler - Unit tests for XTracker::Pick::Scheduler

=cut

use Carp;
use List::Util qw/ first /;
use Data::Dumper;

use Test::MockModule;


use XT::Domain::PRLs;
use XTracker::Constants::FromDB qw/
    :allocation_item_status
    :allocation_status
    :prl
    :shipment_item_status
    :shipment_status
    :shipment_type
/;
use XTracker::Constants qw/ $APPLICATION_OPERATOR_ID /;
use vars qw/$PRL__DEMATIC $PRL__FULL $PRL__GOH/;

use XTracker::Pick::Scheduler;
use XTracker::Pick::PrlCapacity;
use XTracker::Database::Shipment;

use Test::XTracker::Pick::TestScheduler;

use Test::XT::Fixture::Fulfilment::Shipment;
use Test::XT::Fixture::PackingException::Shipment;
use Test::XTracker::Artifacts::RAVNI;

BEGIN {

has products => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return [ Test::XTracker::Data->create_test_products() ];
    },
);

sub prl_rs              { shift->schema->resultset("Public::Prl")->filter_active }
sub runtime_property_rs { shift->schema->resultset("Public::RuntimeProperty") }

has prl_rows => (
    is      => "ro",
    lazy    => 1,
    default => sub { return [ shift->prl_rs->all ] },
);

} # BEGIN

sub prl_row_for_id {
    my ($self, $id) = @_;
    return $self->prl_rs->find($id);
}
sub full_prl_row { shift->prl_row_for_id($PRL__FULL) }
sub dcd_prl_row  { shift->prl_row_for_id($PRL__DEMATIC) }
sub goh_prl_row  { shift->prl_row_for_id($PRL__GOH) }

# $type spec keys:
# fixtures            => [ $fixture object ]
# prl_ids             => [ $PRL__NAME ]
# prl_name_pid_counts => { name => $pid_count, name2 => $pid_count2 }
sub fixtures {
    my ($self, $type_spec) = @_;

    my @fixtures;

    # $fixture objects
    push( @fixtures, @{ $type_spec->{fixtures} // [] } );

    # e.g. { Dematic => 4, Full => 3 }
    push(
        @fixtures,
        map {
            Test::XT::Fixture::Fulfilment::Shipment->new({
                # Can't reuse pids => $self->products if we
                # want specific PRLs
                prl_pid_counts => $_,
            });
        }
        grep { defined }
        ( $type_spec->{prl_name_pid_counts} ),
    );

    # e.g. $PRL__FULL
    push(
        @fixtures,
        map {
            Test::XT::Fixture::Fulfilment::Shipment->new({
                pids   => $self->products,
                prl_id => $_,
            });
        }
        @{ $type_spec->{prl_ids} // [] },
    );

    return \@fixtures;
}

sub test__shipments_to_process_rs : Tests() {
    my $self = shift;

    Test::XT::Fixture::Fulfilment::Shipment
        ->new({ pids => $self->products })
        ->with_allocated_shipment();

    my $pick_scheduler = XTracker::Pick::Scheduler->new();

    ok(
        $pick_scheduler->shipments_to_schedule_rs->count(),
        "Basic sanity check for shipments_to_schedule_rs",
    );
}

sub test__process_allocations__init : Tests() {
    my $self = shift;

    my $pick_scheduler = XTracker::Pick::Scheduler->new();
    $pick_scheduler->schedule_allocations();
    ok(1);
}

sub setup_pick_scheduler_limited_to_fixtures {
    my ($self, $fixtures, $args) = @_;
    $args //= {};

    my @shipment_rows =
        sort { $a->id <=> $b->id } # deterministic order
        map  { $_->shipment_row }
        @$fixtures;
    my @shipment_ids = map { $_->id } @shipment_rows;
    my $pick_scheduler = Test::XTracker::Pick::TestScheduler->new({
        test_shipment_ids => [ @shipment_ids ],
        %$args,
    });

    my @allocation_rows =
        sort { $a->id <=> $b->id } # deterministic order
        map  { $_->allocations }
        @shipment_rows;

    return ($pick_scheduler, \@shipment_rows, \@allocation_rows);
}

sub test_allocation_status {
    my ($self, $description, $allocation_rows, $expected_prl_name_status_id) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    note scalar(@$allocation_rows) . " allocations";

    my $actual_prl_name_status_ids = {};
    for my $allocation_row (sort {$a->id <=> $b->id} @$allocation_rows ) {
        $allocation_row->discard_changes();
        my $prl_name = $allocation_row->prl->name;
        my $allocation_id = $allocation_row->id;
        my $status_id = $allocation_row->status_id;
        my $status_name = $self->search_one(AllocationStatus => {
            id => $status_id,
        })->status;

        note "    $description: ($prl_name) allocation ($allocation_id) allocation_status ($status_id: $status_name)";

        my $allocation_status_ids = $actual_prl_name_status_ids->{$prl_name} //= [];
        push(@$allocation_status_ids, $status_id);
    }

    cmp_deeply(
        $actual_prl_name_status_ids,
        $expected_prl_name_status_id,
        "Allocation statuses ok",
    ) or diag("actual fulfilments" . Dumper($actual_prl_name_status_ids));
}

sub test_runtime_property {
    my ($self, $property_name, $expected_value) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is(
        $self->runtime_property_rs->find_by_name($property_name)->value,
        $expected_value,
        "runtime_property ($property_name) is ($expected_value)",
    );
}

# Reset to a bogus value so we can see it's set properly later on
sub reset_runtime_properties {
    my ($self, $properties, $value) = @_;
    for my $property (@$properties) {
        note "Resetting runtime_property ($property) to ($value)";
        $self->runtime_property_rs->set_property($property, $value);
    }
}

sub test_schedule_allocations_with_fixtures {
    my ($self, $args) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    note $args->{description};

    note "*** Setup";
    my $fixture_map = $args->{fixture_map} // sub { $_ };

    my $fixtures = [
        map { $fixture_map->() }
        @{$self->fixtures( $args->{fixtures} )}
    ];
    my $pick_scheduler_args = $args->{pick_scheduler_args} // {};
    $pick_scheduler_args->{mock_sysconfig_parameter}
        //= $args->{mock_sysconfig_parameter};
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->setup_pick_scheduler_limited_to_fixtures(
        $fixtures,
        $pick_scheduler_args,
    );

    note "Sanity check";
    $self->test_allocation_status(
        "Sanity check",
        $allocation_rows,
        $args->{sanity_check_allocation_status_id} // {
            Full => $ALLOCATION_STATUS__ALLOCATED,
        },
    );

    note "*** Run";
    $pick_scheduler->schedule_allocations();

    note "*** Test";
    note "Correct number in picking";
    $self->test_allocation_status(
        "Test",
        $allocation_rows,
        $args->{allocation_status_ids},
    );

    my $expected_packing_capacity = $args->{expected_packing_capacity};
    if(defined($expected_packing_capacity)) {
        is(
            $pick_scheduler->current_packing_remaining_capacity,
            $expected_packing_capacity,
            "Correct current packing capacity",
        );
    }

    my $expected_picking_capacity = $args->{expected_picking_capacity} // {};
    for my $prl_name ( sort keys %$expected_picking_capacity ) {
        my $expected_prl_picking_capacity
            = $expected_picking_capacity->{ $prl_name };
        my $capacity = $pick_scheduler->capacity_for_prl_name( $prl_name );
        is(
            $capacity->current_picking_remaining_capacity,
            $expected_prl_picking_capacity,
            "Correct remaining picking capacity for PRL ($prl_name)",
        );
    }

    return ( $pick_scheduler, $shipment_rows, $allocation_rows, $fixtures );
}

sub test__process_shipment__error_handling : Tests() {
    my $self = shift;

    my $mock_scheduler = Test::MockModule->new("XTracker::Pick::Scheduler");
    $mock_scheduler->mock(
        process_shipment => sub { die "Oops\n" },
    );
    my $called_ok;
    $mock_scheduler->mock(
        _log_shipment_error => sub {
            my $self = shift;
            my ($shipment_row, $e) = @_;
            note "_log_shipment_error called correctly with e '$e'";
            $called_ok = ($e =~ /Oops/);
        },
    );

    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "schedule_allocation dies ok",
        mock_sysconfig_parameter          => {
            full_picking_total_capacity => 100, # Picking not a problem
        },
        fixtures                          => { prl_ids => [ $PRL__FULL ] },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 1, # Room for one more in packing
        },
        sanity_check_allocation_status_id => { Full => [ $ALLOCATION_STATUS__ALLOCATED ] },

        test_description                  => "Error caught ok",
        allocation_status_ids             => { Full => [ $ALLOCATION_STATUS__ALLOCATED ] },
        expected_packing_capacity         => 1, # No more current packing capacity
        expected_picking_capacity         => { full => 100 }, # None picked
    });

    ok($called_ok, "Error was caught ok");
}



### Full, Attempt pick, check staging capacity
sub test__process_shipment__attempt_pick__staging_capacity : Tests() {
    my $self = shift;
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "Two Full in allocated only stagign capacity for one of them",
        mock_sysconfig_parameter          => {
            full_picking_total_capacity => 100, # Picking not a problem
            full_staging_total_capacity => 1,   # Only staging room for one
        },
        fixtures                          => { prl_ids => [ $PRL__FULL, $PRL__FULL ] },
        sanity_check_allocation_status_id => {
            Full => bag(
                $ALLOCATION_STATUS__ALLOCATED,
                $ALLOCATION_STATUS__ALLOCATED,
            ),
        },

        test_description                  => "Pack space allocated for the first one only",
        allocation_status_ids             => {
            Full => bag(
                $ALLOCATION_STATUS__PICKING,
                $ALLOCATION_STATUS__ALLOCATED,
            )
        },
        # Picking capacity reduced, but only with the one that was picked
        expected_picking_capacity         => { full => 99 },
    });

    note "Full picking and staging capacity should have decreased";
    my $capacity = $pick_scheduler->capacity_for_prl($self->full_prl_row);
    is(
        $capacity->current_staging_remaining_capacity,
        0,
        "No more current staging capacity",
    );
}



### Full, Staged: attempt claim induction capacity
sub test__process_shipment__attempt_claim_induction_capacity__happy : Tests() {
    my $self = shift;
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "One Full in staged, increases induction capacity and packing capacity",
        mock_sysconfig_parameter          => {},
        fixtures                          => { prl_ids => [ $PRL__FULL ] },
        fixture_map                       => sub { $_->with_staged_shipment },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 1, # Room for one more in packing
        },
        sanity_check_allocation_status_id => { Full => [ $ALLOCATION_STATUS__STAGED ] },

        test_description                  => "The staged allocations stay in staged, we only count the induction capacity and remaining packing capacity",
        allocation_status_ids             => { Full => [ $ALLOCATION_STATUS__STAGED ] },
        expected_packing_capacity         => 0, # No more current packing capacity
    });

    my $capacity = $pick_scheduler->capacity_for_prl($self->full_prl_row);
    is(
        $capacity->current_induction_remaining_capacity,
        1,
        "The Full Allocation counts towards the induction capacity",
    );
}

sub test__process_shipment__attempt_claim_induction_capacity__two_full_only_one_claims_induction_capacity : Tests() {
    my $self = shift;
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "Two Full in staged, only pack space for one",
        mock_sysconfig_parameter          => {},
        fixtures                          => {
            prl_ids => [$PRL__FULL, $PRL__FULL], # One allocation_item per allocation
        },
        fixture_map                       => sub { $_->with_staged_shipment },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 1, # Room for one more in packing
        },
        sanity_check_allocation_status_id => {
            Full => [
                $ALLOCATION_STATUS__STAGED,
                $ALLOCATION_STATUS__STAGED,
            ],
        },

        test_description                  => "The staged allocations stay in staged, we only count the induction capacity and remaining packing capacity",
        allocation_status_ids             => {
            Full => [
                $ALLOCATION_STATUS__STAGED,
                $ALLOCATION_STATUS__STAGED,
            ],
        },
        expected_packing_capacity         => 0, # No more current packing capacity
    });

    my $capacity = $pick_scheduler->capacity_for_prl($self->full_prl_row);
    is(
        $capacity->current_induction_remaining_capacity,
        1,
        "Only one Full Allocation counts towards the induction capacity",
    );
}

# Induction, packing: many single-item allocations in one container
# induction is counted in containers, not allocations
sub test__process_shipment__induction_capacity__many_single_item_allocations_in_one_container : Tests() {
    my $self = shift;

    my $fixture1 = Test::XT::Fixture::Fulfilment::Shipment
        ->new({
            pids   => $self->products,
            prl_id => $PRL__FULL,
        })
        ->with_staged_shipment;
    my $fixture2 = Test::XT::Fixture::Fulfilment::Shipment
        ->new({
            pids   => $self->products,
            prl_id => $PRL__FULL,
        })
        ->with_staged_shipment;
    $fixture1->with_shipment_item_moved_into(
        $fixture2->shipment_row->shipment_items->first,
        $fixture1->picked_container_row,
    );

    note "*** Sanity check";
    is_deeply(
        [ $fixture1->picked_container_row->id ],
        [ $fixture1->shipment_row->shipment_items->get_column('container_id')->all ],
        "All shipment_items in fixture1 is in the first container",
    );
    is_deeply(
        [ $fixture1->picked_container_row->id ],
        [ $fixture2->shipment_row->shipment_items->get_column('container_id')->all ],
        "All shipment_items in fixture2 is in the first container",
    );

    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "Many single-item in staged, induction capacity reduced by 1 tote",
        mock_sysconfig_parameter          => {},
        fixtures                          => { fixtures => [ $fixture1, $fixture2 ] },
        fixture_map                       => sub { $_ },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 100, # Plenty of room in packing
        },
        sanity_check_allocation_status_id => {
            Full => [
                $ALLOCATION_STATUS__STAGED,
                $ALLOCATION_STATUS__STAGED,
            ],
        },
        test_description                  => "Induction capacity reduced by 1 tote, not 2 allocations",
        allocation_status_ids             => {
            Full => [
                $ALLOCATION_STATUS__STAGED,
                $ALLOCATION_STATUS__STAGED,
            ],
        },
        expected_packing_capacity         => 100 - 1,
    });

    my $capacity = $pick_scheduler->capacity_for_prl($self->full_prl_row);
    is(
        $capacity->current_induction_remaining_capacity,
        1,
        "Induction capacity increased by number of totes (i.e. 1)",
    );
}


# Induction, packing: multi-item allocation in many containers:
# induction is counted in containers, not allocations
sub test__process_shipment__induction_capacity__multi_item_allocation_in_many_containers : Tests() {
    my $self = shift;

    my $fixture = Test::XT::Fixture::Fulfilment::Shipment
        ->new({
            pids   => [ ( @{$self->products} ) x 3 ],
            prl_id => $PRL__FULL,
        })
        ->with_staged_shipment()
        ->with_shipment_items_moved_into_additional_containers(); # in total 3

    note "*** Sanity check";
    is_deeply(
        $fixture->shipment_row->shipment_items->containers->count,
        3,
        "All shipment_items picked into 3 containers",
    );

    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "One Full multi-item in staged, induction capacity reduced by 3 totes",
        mock_sysconfig_parameter          => {},
        fixtures                          => { fixtures => [ $fixture ] },
        fixture_map                       => sub { $_ },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 1, # A but of room in packing, but only one container (which is enough)
        },
        sanity_check_allocation_status_id => {
            Full => [
                $ALLOCATION_STATUS__STAGED,
            ],
        },
        test_description                  => "Induction capacity reduced by 3 totes, not 1 allocation",
        allocation_status_ids             => {
            Full => [
                $ALLOCATION_STATUS__STAGED,
            ],
        },
        expected_packing_capacity         => -2,
    });

    my $capacity = $pick_scheduler->capacity_for_prl($self->full_prl_row);
    is(
        $capacity->current_induction_remaining_capacity,
        3,
        "Induction capacity increased by number of totes (i.e. 3)",
    );
}





### DCD, Attempt pick, check packing capacity, update pack capacity
sub test__process_shipment__attempt_pick_dcd__happy : Tests() {
    my $self = shift;
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "One DCD in allocated, decreases packing and picking remaining capacity",
        mock_sysconfig_parameter          => {
            dcd_picking_total_capacity => 100, # Picking not a problem
        },
        fixtures                          => { prl_ids => [ $PRL__DEMATIC ] },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 1, # Room for one more in packing
        },
        sanity_check_allocation_status_id => { Dematic => [ $ALLOCATION_STATUS__ALLOCATED ] },

        test_description                  => "The allocated allocations are now in PICKING",
        allocation_status_ids             => { Dematic => [ $ALLOCATION_STATUS__PICKING ] },
        expected_packing_capacity         => 0, # No more current packing capacity
        expected_picking_capacity         => { dcd => 99 }, # Picked one
    });
}

### DCD, Attempt pick, no pack capacity
sub test__process_shipment__attempt_pick_dcd__no_pack_capacity : Tests() {
    my $self = shift;
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "One DCD in allocated, no packing capacity",
        mock_sysconfig_parameter          => {
            dcd_picking_total_capacity => 100, # Picking not a problem
        },
        fixtures                          => { prl_ids => [ $PRL__DEMATIC ] },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 0, # No more packing capacity
        },
        sanity_check_allocation_status_id => { Dematic => [ $ALLOCATION_STATUS__ALLOCATED ] },

        test_description                  => "Could not be picked, still in ALLOCATED",
        allocation_status_ids             => { Dematic => [ $ALLOCATION_STATUS__ALLOCATED ] },
        expected_packing_capacity         => 0, # Still no packing capacity
        expected_picking_capacity         => { dcd => 100 }, # Still the same
    });
}


### DCD, Attempt pick, no pick capacity
sub test__process_shipment__attempt_pick_dcd__no_picking_capacity : Tests() {
    my $self = shift;
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "One DCD in allocated, no picking capacity",
        mock_sysconfig_parameter          => {
            dcd_picking_total_capacity => 0, # Can't pack
        },
        fixtures                          => { prl_ids => [ $PRL__DEMATIC ] },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 1, # Room for one more in packing
        },
        sanity_check_allocation_status_id => { Dematic => [ $ALLOCATION_STATUS__ALLOCATED ] },

        test_description                  => "The allocated allocations are now in PICKING",
        allocation_status_ids             => { Dematic => [ $ALLOCATION_STATUS__ALLOCATED ] },
        expected_packing_capacity         => 1, # No pick, same packing capacity
        expected_picking_capacity         => { dcd => 0 }, # Still the same
    });
}



### Full + DCD

### Full+DCD, Attempt pick, only Full gets picked
sub test__process_shipment__attempt_pick_full_dcd__only_full_picked__dcd_triggered_at_induction : Tests() {
    my $self = shift;

    note "Try to pick both allocations";
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
        $fixtures,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "Full+DCD allocated, only Full gets picked",
        mock_sysconfig_parameter          => {
            full_picking_total_capacity => 100, # Plenty of picking capacity
            dcd_picking_total_capacity  => 100, # Plenty of picking capacity
        },
        fixtures                          => {
            prl_name_pid_counts => {Dematic => 1, Full => 1},
        },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 100, # Plenty packing capacity
        },
        sanity_check_allocation_status_id => {
            Full    => [ $ALLOCATION_STATUS__ALLOCATED ],
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
        },

        test_description                  => "Full allocation in picking, Dematic in allocated",
        allocation_status_ids             => {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__PICKING ],
        },
        expected_packing_capacity         => 100, # Same, still not at packing
        expected_picking_capacity         => { full => 99, dcd => 100 }, # Picking Full
    });



    note "*** Setup: Get Full to staging";
    my $full_allocation_row =
        first { $_->prl_id == $PRL__FULL }
        @$allocation_rows;
    my ($container_id) = Test::XTracker::Data::Order->stage_shipment(
        $full_allocation_row->shipment,
    );

    note "Sanity check";
    $self->test_allocation_status(
        "Sanity check",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__STAGED ],
        },
    );

    note "*** Run";
    $pick_scheduler->schedule_allocations();

    note "*** Test: DCD not triggered";
    $self->test_allocation_status(
        "Test staged",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__STAGED ],
        },
    );



    note "*** Setup: Induct Full";
    my $container_row = $self->schema->find(Container => $container_id);
    $fixtures->[0]->with_container_inducted($container_row);

    note "*** Test: DCD not yet triggered";
    $self->test_allocation_status(
        "Test inducted",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__PICKED ],
        },
    );


    note "*** Setup: Run PS";
    $pick_scheduler->schedule_allocations();

    note "*** Test: DCD pick triggered";
    $self->test_allocation_status(
        "Test inducted",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__PICKING ],
            Full    => [ $ALLOCATION_STATUS__PICKED ],
        },
    );

}

### Full+DCD, Full part completely short picked/cancelled, DCD gets picked
sub test__process_shipment__attempt_pick_full_dcd__full_nothing_to_pick__dcd_pick : Tests() {
    my $self = shift;

    foreach my $test (
        {
            'description'                 => 'Full allocation short picked',
            'full_allocation_item_status' => $ALLOCATION_ITEM_STATUS__SHORT,
            'full_allocation_status'      => $ALLOCATION_STATUS__STAGED,
        },
        {
            'description'                 => 'Full allocation failed and cancelled',
            'full_allocation_item_status' => $ALLOCATION_ITEM_STATUS__CANCELLED,
            'full_allocation_status'      => $ALLOCATION_STATUS__ALLOCATED,
        }
    ) {
        note $test->{description}." - Set up allocations and pick scheduler";

        my (
            $pick_scheduler,
            $shipment_rows,
            $allocation_rows,
        ) = $self->setup_pick_scheduler_limited_to_fixtures(
            $self->fixtures({
                prl_name_pid_counts => {Dematic => 1, Full => 1},
            }),
        );

        note "Get Full allocation in test state - ".$test->{description};
        my $full_allocation_row
            = first { $_->prl_id == $PRL__FULL } @$allocation_rows;

        $full_allocation_row->update({
           status_id => $test->{full_allocation_status}
        });
        $full_allocation_row->allocation_items->update({
            status_id => $test->{full_allocation_item_status}
        });

        note "*** Run pick scheduler";
        $pick_scheduler->schedule_allocations();

        note "*** Test: DCD pick triggered, Full allocation unchanged";
        $self->test_allocation_status(
            "Test DCD pick",
            $allocation_rows,
            {
                Dematic => [ $ALLOCATION_STATUS__PICKING ],
                Full    => [ $test->{full_allocation_status} ],
            },
        );
    }

}

### Full+GOH+DCD, Full part cancelled, DCD blocked by GOH until GOH is short picked

sub test__process_shipment__dcd_blocked_until_all_other_allocations_cancelled_or_short : Tests() {
    my $self = shift;

    SKIP: {
        # TODO: If I could make t/20-units/class/Test/XTracker/Pick/Scheduler/GohActive.pm
        # run at all on my VM, this would go in there for now, but I can't.
        skip 'Only in PRL phase 2+', 1 unless $prl_rollout_phase >= 2;

        note "Try to pick all allocations";
        my (
            $pick_scheduler,
            $shipment_rows,
            $allocation_rows,
            $fixtures,
        ) = $self->setup_pick_scheduler_limited_to_fixtures(
            $self->fixtures({
                prl_name_pid_counts => {Dematic => 1, Full => 1, GOH => 1},
            }),
        );

        note "Sanity check";
        $self->test_allocation_status(
            "Sanity check",
            $allocation_rows,
            {
                Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
                Full    => [ $ALLOCATION_STATUS__ALLOCATED ],
                GOH     => [ $ALLOCATION_STATUS__ALLOCATED ],
            },
        );

        note "Cancel Full allocation";
        my $full_allocation_row
            = first { $_->prl_id == $PRL__FULL } @$allocation_rows;

        $full_allocation_row->allocation_items->update({
            status_id => $ALLOCATION_ITEM_STATUS__CANCELLED
        });

        note "*** Run pick scheduler";
        $pick_scheduler->schedule_allocations();

        note "*** Test: DCD pick not triggered, Full allocation unchanged, GOH pick triggered";
        $self->test_allocation_status(
            "Test DCD pick",
            $allocation_rows,
            {
                Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
                Full    => [ $ALLOCATION_STATUS__ALLOCATED ],
                GOH     => [ $ALLOCATION_STATUS__PICKING ],
            },
        );

        note "*** Run pick scheduler again while GOH is being picked";
        $pick_scheduler->schedule_allocations();

        note "*** Test: DCD pick not triggered, Full allocation unchanged, GOH pick still picking";
        $self->test_allocation_status(
            "Test DCD pick",
            $allocation_rows,
            {
                Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
                Full    => [ $ALLOCATION_STATUS__ALLOCATED ],
                GOH     => [ $ALLOCATION_STATUS__PICKING ],
            },
        );

        note "Short pick GOH allocation";
        my $goh_allocation_row
            = first { $_->prl_id == $PRL__GOH } @$allocation_rows;

        $goh_allocation_row->update({
           status_id => $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE
        });
        $goh_allocation_row->allocation_items->update({
            status_id => $ALLOCATION_ITEM_STATUS__SHORT
        });

        note "*** Run pick scheduler again after GOH is short picked";
        $pick_scheduler->schedule_allocations();

        note "*** Test: DCD pick triggered, Full allocation unchanged, GOH pick unchanged";
        $self->test_allocation_status(
            "Test DCD pick",
            $allocation_rows,
            {
                Dematic => [ $ALLOCATION_STATUS__PICKING ],
                Full    => [ $ALLOCATION_STATUS__ALLOCATED ],
                GOH     => [ $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE ],
            },
        );

    }
}
### GOH+DCD, GOH split over more than one allocation

sub test__process_shipment__multiple_goh_allocations_together__one_dcd_allocation : Tests() {
    my $self = shift;

    SKIP: {
        # TODO: If I could make t/20-units/class/Test/XTracker/Pick/Scheduler/GohActive.pm
        # run at all on my VM, this would go in there for now, but I can't.
        skip 'Only in PRL phase 2+', 1 unless $prl_rollout_phase >= 2;

        note "Try to pick all allocations";
        my (
            $pick_scheduler,
            $shipment_rows,
            $allocation_rows,
            $fixtures,
        ) = $self->test_schedule_split_goh_with_dcd();

        note "*** Setup: Get both GOH allocations to pick complete";
        my (@container_ids) = $fixtures->[0]->shipment_pick_complete;

        note "Sanity check";
        $self->test_allocation_status(
            "Sanity check",
            $allocation_rows,
            {
                Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
                GOH     => [
                             $self->goh_prl_row->pick_complete_allocation_status,
                             $self->goh_prl_row->pick_complete_allocation_status
                           ],
            },
        );

        note "*** Run";
        $pick_scheduler->schedule_allocations();

        note "*** Test: Prepare sent for both GOH allocations, DCD pick triggered";
        $self->test_allocation_status(
            "Test prepare",
            $allocation_rows,
            {
                Dematic => [ $ALLOCATION_STATUS__PICKING ],
                GOH     => [
                             $ALLOCATION_STATUS__PREPARING,
                             $ALLOCATION_STATUS__PREPARING
                           ],
           },
        );

    }
}

sub test__process_shipment__multiple_goh_allocations_separate__one_dcd_allocation : Tests() {
    my $self = shift;

    SKIP: {
        skip 'Only in PRL phase 2+', 1 unless $prl_rollout_phase >= 2;

        note "Try to pick all allocations";
        my (
            $pick_scheduler,
            $shipment_rows,
            $allocation_rows,
            $fixtures,
        ) = $self->test_schedule_split_goh_with_dcd();

        note "*** Setup: Get just one GOH allocation to pick complete";
        my ($goh_allocation_row_1, $goh_allocation_row_2) =
            grep { $_->prl_id == $PRL__GOH }
            sort { $a->id <=> $b->id } @$allocation_rows;
        Test::XTracker::Data::Order->allocation_pick_complete($goh_allocation_row_1);

        note "Sanity check";
        $self->test_allocation_status(
            "Sanity check",
            $allocation_rows,
            {
                Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
                GOH     => [
                             $self->goh_prl_row->pick_complete_allocation_status,
                             $ALLOCATION_STATUS__PICKING,
                           ],
            },
        );

        note "*** Run";
        $pick_scheduler->schedule_allocations();

        note "*** Test: Prepare sent for first GOH allocation, DCD pick sent, other GOH unchanged";
        # The pick is sent for the DCD allocation now, because the first GOH allocation has already
        # allocated pack space for this shipment.
        $self->test_allocation_status(
            "Test prepare",
            $allocation_rows,
            {
                Dematic => [ $ALLOCATION_STATUS__PICKING ],
                GOH     => [
                             $ALLOCATION_STATUS__PREPARING,
                             $ALLOCATION_STATUS__PICKING
                           ],
           },
        );

        note "Get the other GOH allocation to pick complete";
        Test::XTracker::Data::Order->allocation_pick_complete($goh_allocation_row_2);

        note "*** Run";
        $pick_scheduler->schedule_allocations();

        note "*** Test: Prepare sent for second GOH allocation";
        $self->test_allocation_status(
            "Test prepare",
            $allocation_rows,
            {
                Dematic => [ $ALLOCATION_STATUS__PICKING ],
                GOH     => [
                             $ALLOCATION_STATUS__PREPARING,
                             $ALLOCATION_STATUS__PREPARING
                           ],
           },
        );

    }
}



### Short picks

## triggering

# DCD + Full short
# DCD + GOH short

# DCD + Full short + GOH
# DCD + Full + GOH short
# DCD + Full short + GOH short



### Replacement items

sub test_shipment {
    my ($self, $shipment_row, $tests) = @_;

    my $allocation_rows = [ $shipment_row->allocations ];
    is(
        @$allocation_rows + 0,
        $tests->[0]->[0],
        $tests->[0]->[1],
    );

    my $allocation_item_rows = [
        $shipment_row->allocations->search_related("allocation_items"),
    ];
    is(
        @$allocation_item_rows + 0,
        $tests->[1]->[0],
        $tests->[1]->[1],
    );

    my $shipment_item_rows = [ $shipment_row->shipment_items ];
    is(
        @$shipment_item_rows + 0,
        $tests->[2]->[0],
        $tests->[2]->[1],
    );
}

sub test__picked__pe__replacement_item : Tests() {
    my $self = shift;

    note "*** Setup Full picked Shipment in PE, with a replacement pick";

    # Vanilla data object to instatiate fixture without a flow mech dependency
    my $data = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );
    my $fixture = Test::XT::Fixture::PackingException::Shipment
        ->new({ flow => $data })
        ->with_picked_shipment()
        ->with_packed_shipment()
        ->with_picked_container_in_commissioner();


    note "** Sanity check";
    note "Shipment goes to PE, one garment fails QC, replacement pick is issued";
    my $shipment_row = $fixture->shipment_row;

    $self->test_shipment(
        $shipment_row,
        [
            [ 1 => "Start off with 1 allocation in the shipment" ],
            [ 2 => "Start off with 2 allocation_items in the shipment" ],
            [ 2 => "Start off with 2 shipment_items in the shipment" ],
        ],
    );


    note "* Missing at Packing";
    $fixture->with_missing_item();

    note "* When it goes off hold, reallocation, allocate_response";
    $fixture->with_reallocated_missing_item();

    note "** Sanity check there is another allocation, allocation_item";
    $self->test_shipment(
        $shipment_row,
        [
            [ 2 => "After going off hold, another allocation in the shipment" ],
            [ 3 => "... and another allocation_item" ],
            [ 2 => "Still 2 shipment_items" ],
        ],
    );


    note "*** Run PS";
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "Run PS with current fixture",
        mock_sysconfig_parameter          => {},
        fixtures                          => { fixtures => [ $fixture ] },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 100, # Plenty of packing
        },
        sanity_check_allocation_status_id => {
            Full => bag(
                $ALLOCATION_STATUS__PICKED,     # Initial allocation
                $ALLOCATION_STATUS__ALLOCATED,  # Repick allocation
            ),
        },
        test_description                  => "One allocation in PICKED, one newly put into PICKING",
        allocation_status_ids             => {
            Full => bag(
                $ALLOCATION_STATUS__PICKED,   # Initial allocation
                $ALLOCATION_STATUS__PICKING,  # Repick allocation
            ),
        },
        expected_packing_capacity         => 100, # Same
    });


    note "*** Test - new allocation should be in picking";

}

sub test_schedule_split_goh_with_dcd {
    my $self = shift;

    return $self->test_schedule_allocations_with_fixtures({
        description                       => "GOH+DCD allocated, only GOH gets picked",
        mock_sysconfig_parameter          => {
            goh_picking_total_capacity => 100, # Plenty of picking capacity
            dcd_picking_total_capacity  => 100, # Plenty of picking capacity
        },
        fixtures                          => {
            prl_name_pid_counts => {
                Dematic => 1,
                GOH     => $self->goh_prl_row->max_allocation_items + 1, # Should be split into 2 GOH allocations
            },
        },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 100, # Plenty packing capacity
        },
        sanity_check_allocation_status_id => {
            GOH    => [ $ALLOCATION_STATUS__ALLOCATED, $ALLOCATION_STATUS__ALLOCATED ],
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
        },
        test_description                  => "GOH allocations in picking, Dematic in allocated",
        allocation_status_ids             => {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            GOH    => [ $ALLOCATION_STATUS__PICKING, $ALLOCATION_STATUS__PICKING ],
        },
        expected_packing_capacity         => 100, # Same, still not at packing
        expected_picking_capacity         => { goh => 98, dcd => 100 }, # Picking GOH
    });

}

sub mixed_shipment__dcd_part_is_picked_regardless_packing_capacity : Tests() {
    my $self = shift;

    # This test is based on bug DCA-4170.
    #
    # Pick Scheduler to release Dematic part of mixed shipment
    # (Dematic + Full allocations) whenever Full counterpart is
    # ready for packing, regardless remaining packing capacity.

    my $args = {
        mock_sysconfig_parameter => {
            full_picking_total_capacity => 100,
            dcd_picking_total_capacity  => 100,
        },
        fixtures => {
            prl_name_pid_counts => {Dematic => 1, Full => 1},
        },
        pick_scheduler_args => {
            # Leave initial remaining packing capacity to be 1
            # so it is only enough to process Full part
            packing_remaining_capacity => 1,
        },
    };

    my $fixtures = $self->fixtures( $args->{fixtures} );
    my $pick_scheduler_args = $args->{pick_scheduler_args};
    $pick_scheduler_args->{mock_sysconfig_parameter}
        //= $args->{mock_sysconfig_parameter};
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->setup_pick_scheduler_limited_to_fixtures(
        $fixtures,
        $pick_scheduler_args,
    );

    note "Sanity check";
    $self->test_allocation_status(
        "Full and Dematic allocations are in allocated status",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__ALLOCATED ],
        },
    );


    note "Run pick schedule";
    $pick_scheduler->schedule_allocations;
    $_->discard_changes for @$allocation_rows;
    $self->test_allocation_status(
        "... and check that Full allocation moved into picking status,"
        . " Dematic one still waits",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__PICKING ],
        },
    );


    note "Get Full part to staging";
    my $full_allocation_row =
        first { $_->prl_id == $PRL__FULL }
        @$allocation_rows;
    my ($container_id) = Test::XTracker::Data::Order->stage_shipment(
        $full_allocation_row->shipment,
    );
    $_->discard_changes for @$allocation_rows;
    $self->test_allocation_status(
        "... and check that Full allocation is staged",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__STAGED ],
        },
    );


    note "Run pick scheduler";
    $pick_scheduler->schedule_allocations;
    $_->discard_changes for @$allocation_rows;
    $self->test_allocation_status(
        "... and check that Dematic allocation was not changed",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__STAGED ],
        },
    );


    note "Induct Full allocation";
    my $container_row = $self->schema->find(Container => $container_id);
    $fixtures->[0]->with_container_inducted($container_row);
    $_->discard_changes for @$allocation_rows;
    $self->test_allocation_status(
        "... so Full allocation is picked now",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__ALLOCATED ],
            Full    => [ $ALLOCATION_STATUS__PICKED ],
        },
    );

    is(
        $pick_scheduler->current_packing_remaining_capacity,
        0,
        "Packing area is full, no more capacity is left"
    );


    note "Run pick scheduler";
    $pick_scheduler->schedule_allocations;
    $_->discard_changes for @$allocation_rows;
    $self->test_allocation_status(
        "...and check that Dematic allocation is in picking",
        $allocation_rows,
        {
            Dematic => [ $ALLOCATION_STATUS__PICKING ],
            Full    => [ $ALLOCATION_STATUS__PICKED ],
        },
    );
}

sub test_cancelled_order_after_goh_picking : Tests {
    my $self = shift;

    SKIP: {
        skip 'Only in PRL phase 2+', 1 unless $prl_rollout_phase >= 2;

        my (
            $pick_scheduler,
            $shipment_rows,
            $allocation_rows,
            $fixtures,
        ) = $self->setup_pick_scheduler_limited_to_fixtures(
            $self->fixtures({
                prl_name_pid_counts => {GOH => 1},
            }),
        );

        note "Sanity check";
        $self->test_allocation_status(
            "Sanity check",
            $allocation_rows,
            {
                GOH    => [ $ALLOCATION_STATUS__ALLOCATED ],
            },
        );


        note "Run pick scheduler";
        $pick_scheduler->schedule_allocations;
        $self->test_allocation_status(
            "Check that GOH allocation moved into picking status",
            $allocation_rows,
            {
                GOH    => [ $ALLOCATION_STATUS__PICKING ],
            },
        );

        my $goh_allocation = $allocation_rows->[0];

        Test::XTracker::Data::Order->allocation_pick_complete( $goh_allocation );

        $goh_allocation->discard_changes;
        is ($goh_allocation->status_id, $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE,
            "Allocation status is now allocating pack space");

        note "Now cancel the whole shipment";
        Test::XTracker::Data::Order->cancel_shipment($goh_allocation->shipment);

        is ($goh_allocation->shipment->shipment_status_id, $SHIPMENT_STATUS__CANCELLED,
            "Shipment status is now cancelled for shipment id ".$goh_allocation->shipment->id);
        foreach my $shipment_item ($goh_allocation->shipment->shipment_items) {
            is ($shipment_item->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                "Shipment item status is now cancel pending for shipment_item id ".$shipment_item->id);
        }

        note "Run pick scheduler again and check that prepare is sent";

        my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
        $pick_scheduler->schedule_allocations;
        $goh_allocation->discard_changes;

        is ($goh_allocation->status_id, $ALLOCATION_STATUS__PREPARING,
            "Allocation status is now preparing");

        $xt_to_prl->expect_messages({
            messages => [ {
                type    => 'prepare',
                path    => $goh_allocation->prl->amq_queue,
                details => {
                    allocation_id => $goh_allocation->id,
                    destination   =>
                        $goh_allocation->get_prl_delivery_destination->
                            message_name,
                },
            } ],
        });
    }

}

sub test_wind_down_pick_scheduler :Tests {
    my $self = shift;

    # generate a regular shipment.
    my $regular1 = Test::XT::Fixture::Fulfilment::Shipment->new({
        pids   => $self->products,
        prl_id => $PRL__FULL,
    });
    $regular1->shipment_row->discard_changes;

    # generate a premier shipment.
    my $premier1 = Test::XT::Fixture::Fulfilment::Shipment->new({
        pids   => $self->products,
        prl_id => $PRL__FULL,
    });
    $premier1->shipment_row->update({ shipment_type_id => $SHIPMENT_TYPE__PREMIER });
    $premier1->shipment_row->discard_changes;

    # mock check to ensure they are evaluated.
    my $evaluated = {};
    my $mock_scheduler = Test::MockModule->new("XTracker::Pick::Scheduler");
    $mock_scheduler->mock('_after_wind_down_cutoffs', sub {
        my ($self, $shipment_row) = @_;
        $evaluated->{$shipment_row->id} = 1;
    });

    # sanity test. no capacity to pick.. but ensure items evaluated
    # by pick scheduler.
    my (
        $pick_scheduler,
        $shipment_rows,
        $allocation_rows,
    ) = $self->test_schedule_allocations_with_fixtures({
        description                       => "No Room but items evaluated",
        mock_sysconfig_parameter          => {
            full_picking_total_capacity => 0, # No room
            full_staging_total_capacity => 0,
        },
        fixtures                          => { fixtures => [ $regular1, $premier1 ] },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 0,
        },
        sanity_check_allocation_status_id => {
            Full => [
                $ALLOCATION_STATUS__ALLOCATED,
                $ALLOCATION_STATUS__ALLOCATED,
        ]},
        test_description                  => "Sanity test. Items evaluated",
        allocation_status_ids             => { Full => [
            $ALLOCATION_STATUS__ALLOCATED,
            $ALLOCATION_STATUS__ALLOCATED,
        ]},
    });

    ok(exists($evaluated->{$regular1->shipment_row->id}), 'Regular Shipment 1 evaluated by pick scheduler');
    ok(exists($evaluated->{$premier1->shipment_row->id}), 'Premier Shipment 2 evaluated by pick scheduler');

    # take a timestamp for rewriting the config.
    # premier shipments after this date won't be evaluated.
    # use sleep(1) either side to remove ambiguity.
    sleep(1);
    my $dt_now = $self->schema->db_now;
    sleep(1);

    $mock_scheduler->unmock('_after_wind_down_cutoffs');

    # mock our own config values.
    my $fake_config_args = {
        sample => undef,
        premier => undef,
        standard => $dt_now
    };
    $pick_scheduler->_cutoff_date_by_type($fake_config_args);

    # ensure all premiers not skipped and the regular before the cut off isn't skipped.
    ok(!$pick_scheduler->_after_wind_down_cutoffs($regular1->shipment_row), 'Include the regular shipment before cutoff');
    ok(!$pick_scheduler->_after_wind_down_cutoffs($premier1->shipment_row), 'Include the premier shipment before cutoff');

    my $regular2 = Test::XT::Fixture::Fulfilment::Shipment->new({
        pids   => $self->products,
        prl_id => $PRL__FULL,
    });
    $regular2->shipment_row->discard_changes;

    note(sprintf("date now: %s, fixture 3 creation date: %s",
        $dt_now->datetime(),
        $regular2->shipment_row->date->datetime()
    ));

    my $premier2 = Test::XT::Fixture::Fulfilment::Shipment->new({
        pids   => $self->products,
        prl_id => $PRL__FULL,
    });
    $premier2->shipment_row->update({ shipment_type_id => $SHIPMENT_TYPE__PREMIER });
    $premier2->shipment_row->discard_changes;

    # ensure we skip non-premier shipments after cut off (regular2) and rest are ok.
    ok(!$pick_scheduler->_after_wind_down_cutoffs($regular1->shipment_row), 'Include the regular shipment before cutoff');
    ok(!$pick_scheduler->_after_wind_down_cutoffs($premier1->shipment_row), 'Include the premier shipment before cutoff');
    ok($pick_scheduler->_after_wind_down_cutoffs($regular2->shipment_row), 'Skip the regular shipment after regular cutoff');
    ok(!$pick_scheduler->_after_wind_down_cutoffs($premier2->shipment_row), 'Include the premier shipment after regular cutoff');

    # run pick scheduler to ensure it uses _after_wind_down_cutoffs
    $self->test_schedule_allocations_with_fixtures({
        description                       => "Process everything available respecting _after_wind_down_cutoffs()",
        mock_sysconfig_parameter          => {
            dcd_picking_total_capacity => 300,
            full_picking_total_capacity => 300,
        },
        fixtures                          => { fixtures => [ $regular1, $premier1, $regular2, $premier2 ] },
        fixture_map                       => sub { $_ },
        pick_scheduler_args               => {
            packing_remaining_capacity    => 400,
            _cutoff_date_by_type          => $fake_config_args
        },
        test_description                  => "Process everything available respecting _after_wind_down_cutoffs()",
        sanity_check_allocation_status_id => {
            Full => [
                $ALLOCATION_STATUS__ALLOCATED,
                $ALLOCATION_STATUS__ALLOCATED,
                $ALLOCATION_STATUS__ALLOCATED,
                $ALLOCATION_STATUS__ALLOCATED
        ]},
        allocation_status_ids             => { Full => [
            $ALLOCATION_STATUS__PICKING,   # before cut off regular
            $ALLOCATION_STATUS__PICKING,   # premier
            $ALLOCATION_STATUS__ALLOCATED, # after cut off regular
            $ALLOCATION_STATUS__PICKING    # premier
        ]}
    });

}

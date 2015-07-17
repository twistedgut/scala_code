package Test::XTracker::PackingRouteChooser::PackingRouteTesting;

use NAP::policy "tt", "test", "class";
use FindBin::libs;

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
};

use Test::XTracker::RunCondition prl_phase => 1;

use Test::XTracker::Data;
use Test::XTracker::Data::PackRouteTests;

our $pt; # Class to call ->premier, etc. on
BEGIN { $pt = "Test::XTracker::Data::PackRouteTests" }

use XTracker::Constants::FromDB qw(
    :pack_lane_attribute
);

sub startup :Tests(startup) {
    my $self = shift;

    $self->SUPER::startup;
    $self->{plt} = Test::XTracker::Data::PackRouteTests->new;

}

sub shutdown_tests :Tests(shutdown) {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());
}

sub test_capacities_simple :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    my $lanes = [{
        pack_lane_id => 12,
        human_name => 'multi_tote_pack_lane_7',
        internal_name => 'DA.PO01.0000.CCTA01NP13',
        capacity => 7,
        active => 1,
        attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
    }, {
        pack_lane_id => 13,
        human_name => 'pack_lane_2',
        internal_name => 'DA.PO01.0000.CCTA01NP14',
        capacity => 14,
        active => 1,
        attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
    }];

    $plt->reset_and_apply_config($lanes);

    $plt->check_lane_capacity('multi_tote_pack_lane_7', 7, 'Checking initial lane capacity multi_tote_pack_lane_12 is 7');
    $plt->check_lane_capacity('pack_lane_2', 14, 'Checking initial lane capacity pack_lane_2 is 14');

}

sub test_like_live_config_expectations :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());
    $plt->check_total_remaining_capacity(165, 'We can track total capacity across all lanes so we do. Total capacity is at 165');
}

sub test_standard_shipment :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    $plt->create_container('M1', $pt->standard, 1, 1);   # creates a standard container with a single shipment.
    $plt->allocate_container_and_test('M1', 'pack_lane_2', 'Test Standard Container M1 goes to packlane two (first nonpremier lane)');
    $plt->container_allocation_logged('M1', 'pack_lane_2', 'Test Log container M1 correct packlane record');
    $plt->check_lane_capacity('pack_lane_2', 22, 'pack_lane_2 has capacity of 23. Ensure this was decremented to 22');

    # lets also quickly check it hasn't been recorded in progress twice.
    $plt->check_unprocessed_item_count(1, 'Check there is one unprocessed item on the conveyor belt');
}

sub test_premier_shipment :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    $plt->create_container('M2', $pt->premier, 1, 1);
    $plt->allocate_container_and_test('M2', 'pack_lane_1', 'Test Premier Container M2 goes to packlane one (only premier lane for single tote)');
    $plt->container_allocation_logged('M2', 'pack_lane_1', 'Test Log container M2 correct packlane record');
    $plt->check_lane_capacity('pack_lane_1', 13, 'pack_lane_1 has capacity of 14. Ensure this was decremented to 13');

    # lets also quickly check it hasn't been recorded in progress twice.
    $plt->check_unprocessed_item_count(1, 'Check there is one unprocessed item on the conveyor belt');

}

sub test_standard_assign_by_capacity :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    my $simple_config = [{
        pack_lane_id => 1,
        human_name => 'pack_lane_1',
        internal_name => 'DA.PO01.0000.CCTA01NP02',
        capacity => 14,
        active => 1,
        attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__SINGLE ]
    }, {
        pack_lane_id => 2,
        human_name => 'pack_lane_2',
        internal_name => 'DA.PO01.0000.CCTA01NP06',
        capacity => 23,
        active => 1,
        attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
    }, {
        pack_lane_id => 3,
        human_name => 'pack_lane_3',
        internal_name => 'DA.PO01.0000.CCTA01NP09',
        capacity => 23,
        active => 1,
        attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
    } ];

    $plt->reset_and_apply_config($simple_config);

    $plt->create_container('M1', $pt->standard, 1, 1);
    $plt->allocate_container_and_test('M1', 'pack_lane_2', 'Test Standard Container M1 goes to packlane two (first nonpremier lane)');
    $plt->container_allocation_logged('M1', 'pack_lane_2', 'Test Log container M1 correct packlane record');
    $plt->check_lane_capacity('pack_lane_2', 22, 'pack_lane_2 has capacity of 23. Ensure this was decremented to 22');

    $plt->create_container('M2', $pt->standard, 1, 1);
    $plt->allocate_container_and_test('M2', 'pack_lane_3', 'Test Standard Container M2 goes to packlane three (next empty lane)');
    $plt->container_allocation_logged('M2', 'pack_lane_3', 'Test Log container M2 correct packlane record');
    $plt->check_lane_capacity('pack_lane_3', 22, 'pack_lane_3 has capacity of 23. Ensure this was decremented to 22');

    $plt->check_total_remaining_capacity(23 + 23 + 14 - 2, 'Capacity for all lanes is 23 + 23 + 14 (look at hash table) - 2 we allocated');
}

sub test_like_live_capacity_checking :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    $plt->create_container('M1', $pt->standard, 1, 1);
    $plt->allocate_container_and_test('M1', 'pack_lane_2', 'M1 should go to pack_lane_2, lowest id, highest capacity for standard single tote package');

    $plt->create_container('M2', $pt->standard, 1, 1);
    $plt->allocate_container_and_test('M2', 'pack_lane_3', 'M2 should go to pack_lane_3, now the lowest id, highest capacity for standard single tote package');

    $plt->create_container('M3', $pt->standard, 1, 1);
    $plt->allocate_container_and_test('M3', 'pack_lane_4', 'M3 should go to pack_lane_4, now the lowest id, highest capacity for standard single tote package');

    $plt->create_container('M4', $pt->standard, 1, 1);
    $plt->allocate_container_and_test('M4', 'pack_lane_2', 'test like live capacity. M4 should go to pack_lane_2');

    $plt->create_container('M5', $pt->standard, 1, 1);
    $plt->allocate_container_and_test('M5', 'pack_lane_3', 'test like live capacity. M5 should go to pack_lane_3');

    $plt->create_container('M6', $pt->standard, 1, 1);
    $plt->allocate_container_and_test('M6', 'pack_lane_4', 'test like live capacity. M6 should go to pack_lane_4');

    $plt->create_container('M7', $pt->standard, 1, 1);
    $plt->allocate_container_and_test('M7', 'pack_lane_2', 'test like live capacity. M7 should go to pack_lane_2');

    for my $i (8..39) {

        $plt->create_container("M$i", $pt->standard, 1, 1);
        $plt->allocate_container("M$i");
    }

    $plt->container_allocation_logged('M31', 'pack_lane_5', 'Expect M31 in pack_lane_5 if algorithm works correctly');
    $plt->container_allocation_logged('M35', 'pack_lane_5', 'Expect M35 in pack_lane_5 if algotithm works correctly');
    $plt->container_allocation_logged('M39', 'pack_lane_5', 'Expect M39 in pack_lane_5 if algotithm works correctly');
    $plt->check_lane_capacity('pack_lane_5', 11, 'pack_lane_5 has capacity of 11');
    $plt->check_lane_capacity('pack_lane_2', 11, 'pack_lane_2 has capacity of 11');

}

sub test_single_lane_overflow :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    # In live, there is only one single lane premier lane.
    # Keep pushing things there until the capacity goes below zero.
    # Then ensure pushing more stuff keeps it at zero.
    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    for my $i (0..15) {
        $plt->create_container("M$i", $pt->premier, 1, 1);
        $plt->allocate_container_and_test("M$i", "pack_lane_1", "Overfill pack lane 1 ($i)");
    }

    $plt->check_lane_capacity('pack_lane_1', -2, 'pack_lane_1 is over capacity at -2');

}

sub test_multitote_stay_together :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    my $config = [ {
            pack_lane_id => 6,
            human_name => 'multi_tote_pack_lane_1',
            internal_name => 'DA.PO01.0000.CCTA01NP03',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 7,
            human_name => 'multi_tote_pack_lane_2',
            internal_name => 'DA.PO01.0000.CCTA01NP05',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 8,
            human_name => 'multi_tote_pack_lane_3',
            internal_name => 'DA.PO01.0000.CCTA01NP07',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }
    ];

    $plt->reset_and_apply_config($config);

    $plt->create_container('M1', $pt->standard, 1, 2);  # standard container 1 of 2 (aka multitote)
    $plt->create_container('M2', $pt->standard, 2, 2, 'M1'); # 2 of 2 (sibling is M1)

    $plt->allocate_container_and_test('M1', 'multi_tote_pack_lane_2', 'Test multi tote go to multi_tote_pack_lane_2 (lowest id, joint highest capacity)');
    $plt->allocate_container_and_test('M2', 'multi_tote_pack_lane_2', 'Test multi tote go to multi_tote_pack_lane_2 (follow the leader!)');

}

sub test_multittote_capacity_assignment {
    my $self = shift;
    my $plt = $self->{'plt'};

    my $config = [ {
            pack_lane_id => 6,
            human_name => 'multi_tote_pack_lane_1',
            internal_name => 'DA.PO01.0000.CCTA01NP03',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 7,
            human_name => 'multi_tote_pack_lane_2',
            internal_name => 'DA.PO01.0000.CCTA01NP05',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 8,
            human_name => 'multi_tote_pack_lane_3',
            internal_name => 'DA.PO01.0000.CCTA01NP07',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }
    ];

    $plt->reset_and_apply_config($config);

    $plt->create_container('M1', $pt->standard, 1, 2);  # standard container 1 of 2 (aka multitote)
    $plt->create_container('M2', $pt->standard, 1, 2);  # M1 and M2 are not related. they should go to different places
    $plt->create_container('M3', $pt->standard, 1, 2);

    $plt->allocate_container_and_test('M1', 'multi_tote_pack_lane_2', 'Test multi tote go to multi_tote_pack_lane_2 (lowest id, joint highest capacity)');
    $plt->allocate_container_and_test('M2', 'multi_tote_pack_lane_3', 'Test multi tote go to multi_tote_pack_lane_3 (lowest id, highest capacity');
    $plt->allocate_container_and_test('M3', 'multi_tote_pack_lane_4', 'Test multi tote go to multi_tote_pack_lane_4 (lowest id, highest capacity');

}

sub test_live_multitote_interlacing :Tests() { # means interlacing different containers with their siblings and ensuring nothing gets confused!
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    # we're going to use 13 containers!  M1-5 are siblings, M6, M8, M10 are siblings, M7 M9 and M12 are siblings and M11 and M13 are premier siblings!
    $plt->create_container('M1', $pt->standard, 1, 5);
    $plt->create_container("M$_", $pt->standard, $_, 5, 'M1') for 2..5;

    $plt->create_container('M6', $pt->standard, 1, 3);  # we're kind of checking container creation doesn't effect results.
    $plt->create_container('M7', $pt->standard, 1, 3);
    $plt->create_container('M8', $pt->standard, 2, 3, 'M6');
    $plt->create_container('M9', $pt->standard, 2, 3, 'M7');
    $plt->create_container('M10', $pt->standard, 3, 3, 'M6');
    $plt->create_container('M11', $pt->premier, 1, 2);
    $plt->create_container('M12', $pt->standard, 3, 3, 'M7');
    $plt->create_container('M13', $pt->premier, 2, 2, 'M11');

    # lets allocate them all
    for my $i (1..13) {
        $plt->allocate_container("M$i");
    }

    # so.. M1-5 should all be in multi_tote_pack_lane_2 (first non premier lane)
    $plt->container_allocation_logged('M1', 'multi_tote_pack_lane_2', 'Expect M1 in multi_tote_pack_lane_2');
    $plt->container_allocation_logged('M2', 'multi_tote_pack_lane_2', 'Expect M2 in multi_tote_pack_lane_2');
    $plt->container_allocation_logged('M3', 'multi_tote_pack_lane_2', 'Expect M3 in multi_tote_pack_lane_2');
    $plt->container_allocation_logged('M4', 'multi_tote_pack_lane_2', 'Expect M4 in multi_tote_pack_lane_2');
    $plt->container_allocation_logged('M5', 'multi_tote_pack_lane_2', 'Expect M5 in multi_tote_pack_lane_2');

    # ...and we expected the gang M6, M8 and M11 to not follow M1 -> M5 and be in the next lane.
    $plt->container_allocation_logged('M6', 'multi_tote_pack_lane_3', 'Expect M6 in multi_tote_pack_lane_3');
    $plt->container_allocation_logged('M8', 'multi_tote_pack_lane_3', 'Expect M8 in multi_tote_pack_lane_3');
    $plt->container_allocation_logged('M10', 'multi_tote_pack_lane_3', 'Expect M11 in multi_tote_pack_lane_3');

    #  gang M7, M9 and M12 in multi_tote_pack_lane_4
    $plt->container_allocation_logged('M7', 'multi_tote_pack_lane_4', 'Expect M7 in multi_tote_pack_lane_4');
    $plt->container_allocation_logged('M9', 'multi_tote_pack_lane_4', 'Expect M9 in multi_tote_pack_lane_4');
    $plt->container_allocation_logged('M12', 'multi_tote_pack_lane_4', 'Expect M12 in multi_tote_pack_lane_4');

    # and finally the premier gang should end up together (not in multi_tote_pack_lane_5)!
    $plt->container_allocation_logged('M11', 'multi_tote_pack_lane_1', 'Expect M11 in multi_tote_pack_lane_1');
    $plt->container_allocation_logged('M13', 'multi_tote_pack_lane_1', 'Expect M13 in multi_tote_pack_lane_1');

}

sub test_disabled_pack_lanes_ignored :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    my $config = [{
            pack_lane_id => 6,
            human_name => 'multi_tote_pack_lane_1',
            internal_name => 'DA.PO01.0000.CCTA01NP03',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 7,
            human_name => 'multi_tote_pack_lane_2',
            internal_name => 'DA.PO01.0000.CCTA01NP05',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 8,
            human_name => 'multi_tote_pack_lane_3',
            internal_name => 'DA.PO01.0000.CCTA01NP07',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 9,
            human_name => 'multi_tote_pack_lane_4',
            internal_name => 'DA.PO01.0000.CCTA01NP08',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }
    ];

    $plt->reset_and_apply_config($config);
    $plt->deactivate_pack_lane('multi_tote_pack_lane_3');

    # these will go this multi_tote_pack_lane_2
    $plt->create_container('M1', $pt->standard, 1, 2);
    $plt->create_container('M2', $pt->standard, 2, 2, 'M1');

    $plt->allocate_container_and_test('M1', 'multi_tote_pack_lane_2', 'Test multi tote go to multi_tote_pack_lane_2');
    $plt->allocate_container_and_test('M2', 'multi_tote_pack_lane_2', 'Test multi tote go to multi_tote_pack_lane_2 (follow the leader)');

    $plt->deactivate_pack_lane('multi_tote_pack_lane_3');

    # these are NEW containers, unrelated to M1 and M2.. check they ignore M3.
    $plt->create_container('M3', $pt->standard, 1, 2);
    $plt->create_container('M4', $pt->standard, 2, 2, 'M3');

    # These will have to go to packlane 4
    $plt->allocate_container_and_test('M3', 'multi_tote_pack_lane_4', 'Skip disabled multi_tote_pack_lane_3 and go to multi_tote_pack_lane4');
    $plt->allocate_container_and_test('M4', 'multi_tote_pack_lane_4', 'Skip disabled multi_tote_pack_lane_3 and go to multi_tote_pack_lane4 (follow the leader)');

}

sub test_disabled_pack_lanes_used :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    my $config = [{
            pack_lane_id => 6,
            human_name => 'multi_tote_pack_lane_1',
            internal_name => 'DA.PO01.0000.CCTA01NP03',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 7,
            human_name => 'multi_tote_pack_lane_2',
            internal_name => 'DA.PO01.0000.CCTA01NP05',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 8,
            human_name => 'multi_tote_pack_lane_3',
            internal_name => 'DA.PO01.0000.CCTA01NP07',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }
    ];

    $plt->reset_and_apply_config($config);
    $plt->deactivate_pack_lane('multi_tote_pack_lane_3');

    # these will go this multi_tote_pack_lane_2
    $plt->create_container('M1', $pt->standard, 1, 4);
    $plt->create_container('M2', $pt->standard, 2, 4, 'M1');

    $plt->allocate_container_and_test('M1', 'multi_tote_pack_lane_2', 'Test multi tote go to multi_tote_pack_lane_2');
    $plt->allocate_container_and_test('M2', 'multi_tote_pack_lane_2', 'Test multi tote go to multi_tote_pack_lane_2 (follow the leader)');

    $plt->deactivate_pack_lane('multi_tote_pack_lane_2');

    # pack lane 2 DISABLED... but containers M3 and M4 MUST FOLLOW THE LEADER

    $plt->create_container('M3', $pt->standard, 3, 4, 'M1');
    $plt->create_container('M4', $pt->standard, 3, 4, 'M1');

    $plt->allocate_container_and_test('M3', 'multi_tote_pack_lane_2', 'Ignore active=false.. follow siblings in multi_tote');
    $plt->allocate_container_and_test('M4', 'multi_tote_pack_lane_2', 'Even more totes in the multitote continue to ignore active=false');

}

sub capacity_counting_including_container_counts :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    my $config = [{
            pack_lane_id => 6,
            human_name => 'multi_tote_pack_lane_1',
            internal_name => 'DA.PO01.0000.CCTA01NP03',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 7,
            human_name => 'multi_tote_pack_lane_2',
            internal_name => 'DA.PO01.0000.CCTA01NP05',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 8,
            human_name => 'multi_tote_pack_lane_3',
            internal_name => 'DA.PO01.0000.CCTA01NP07',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }
    ];

    $plt->reset_and_apply_config($config);

    $plt->check_lane_capacity('multi_tote_pack_lane_2', 7, 'multi_tote_pack_lane_2 capacity is 7');

    $plt->create_container('M1', $pt->standard, 1, 2);
    $plt->allocate_container_and_test('M1', 'multi_tote_pack_lane_2', 'Send M1 to multi_tote_pack_lane_2');

    $plt->check_lane_capacity('multi_tote_pack_lane_2', 6, 'multi_tote_pack_lane_2 capacity is 6 after container put on it.');

    # lets pretend a container count of 1 came from dematic (we use this in capacity calculations)

    $plt->mock_incoming_lane_status_message('multi_tote_pack_lane_2', 1); # one thing in the lane.

    # we don't think our container is in the lane yet (just enroute).. and included in the container_count's value from dematic... so
    # we would expect a capacity value of 5 here. (one enroute, one arrived)

    $plt->check_lane_capacity('multi_tote_pack_lane_2', 5, 'multi_tote_pack_lane_2 capacity is 5 after container put on it.');

    # lets mark the container and having arrived in the pack lane now.
    $plt->mock_container_arrived('M1');

    # now the system thinks the container counted by dematic is the SAME one we just sent...
    # so capacity is total - 1.
    $plt->check_lane_capacity('multi_tote_pack_lane_2', 6, 'multi_tote_pack_lane_2 capacity is 6. Dematic and us think 1, arrived in pack lane.');

}

sub allocation_uses_container_counts :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    my $config = [{
            pack_lane_id => 6,
            human_name => 'multi_tote_pack_lane_1',
            internal_name => 'DA.PO01.0000.CCTA01NP03',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 7,
            human_name => 'pack_lane_2',
            internal_name => 'DA.PO01.0000.CCTA01NP05',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
        }, {
            pack_lane_id => 8,
            human_name => 'pack_lane_3',
            internal_name => 'DA.PO01.0000.CCTA01NP07',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
        }
    ];

    $plt->reset_and_apply_config($config);
    # same test as above. Lets fiddle with the numbers reported by Dematic and ensure that it actually
    # impacts pack lane allocations
    $plt->mock_incoming_lane_status_message('pack_lane_2', 1);

    # now pack_lane_3 is looking good...
    $plt->create_container('M1', $pt->standard, 1, 1);

    $plt->allocate_container_and_test('M1', 'pack_lane_3', 'Ignore pack_lane_2 on container_counts advice');

    $plt->mock_container_arrived('M1');
    $plt->mock_incoming_lane_status_message('pack_lane_3', 1);

    $plt->mock_incoming_lane_status_message('pack_lane_2', 5); # 5 is intentionally a bit random

    $plt->create_container('M1', $pt->standard, 1, 1);
    $plt->allocate_container_and_test('M1', 'pack_lane_3', 'Ignore pack_lane_2 on container_counts advice still');

    $plt->check_lane_capacity('pack_lane_2', 2, 'expected capacity for pack_lane_2 after five items reported is 2');
    $plt->check_lane_capacity('pack_lane_3', 5, 'expected capacity for pack_lane_3 after two items sent is 5');

}

sub sample_single_goes_to_sample_lane :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    $plt->create_container('M1', $pt->samples, 1, 1);
    $plt->allocate_container_and_test('M1', 'seasonal_line', 'Sample single goes to seasonal line');
}

sub sample_multitote_goes_to_sample_lane :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    $plt->create_container('M1', $pt->samples, 1, 2); # multitote
    $plt->allocate_container_and_test('M1', 'seasonal_line', 'Sample multitote goes to seasonal line');

}

sub press_and_transfer_shipment_classes_considered_samples :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    $plt->create_container('M1', $pt->press, 1, 1);
    $plt->allocate_container_and_test('M1', 'seasonal_line', 'Press shipment treated as Sample shipment');

    $plt->create_container('M2', $pt->trans_ship, 1, 1);
    $plt->allocate_container_and_test('M2', 'seasonal_line', 'Transfer Shipment treated as Sample shipment');

}

sub empty_container_goes_somewhere :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    $plt->create_empty_container('M1');

    # In truth, it only detects the container is empty when trying to find out if it's multitote
    # and it replies false, so the code just falls through the standard cases and gets treated
    # as a standard single shipment.

    my $result = $plt->allocate_container('M1');
    isa_ok($result, 'XTracker::Schema::Result::Public::PackLane', 'A packlane was returned for the empty container');

}

sub routing_double_assignment_goes_somewhere :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    # first multitote collection
    $plt->create_container('M1', $pt->premier, 1, 2);
    $plt->create_container('M2', $pt->premier, 2, 2, 'M1');

    $plt->allocate_container_and_test('M1', 'multi_tote_pack_lane_1', 'M1 to premier lane');

    # second multitote collection
    $plt->create_container('M3', $pt->standard, 1, 2);
    $plt->create_container('M4', $pt->standard, 2, 2, 'M3');

    $plt->allocate_container_and_test('M3', 'multi_tote_pack_lane_2', 'M3 to standard lane');

    # take contents of M2 and M4... stuff them into M5
    # to create a situation where M5 needs is associated
    # with both packlanes: multitote_pack_lane_1 and multitote_pack_lane_2
    # (and isn't even multitote!)
    $plt->create_container('M5', $pt->standard, 1, 1);

    $self->schema->resultset('Public::ShipmentItem')->search({
        container_id => { '-in' => [ 'M2', 'M4' ] }
    })->update({
        container_id => 'M5'
    });

    $plt->allocate_container_and_test('M5', 'packing_no_read', 'Badly filled container sent to packing_no_read');
}

sub always_a_default_lane_even_if_no_attribute :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    $self->schema->resultset('Public::PackLaneHasAttribute')->search({
        pack_lane_attribute_id => $PACK_LANE_ATTRIBUTE__DEFAULT
    })->delete;

    my $result = $self->schema->resultset('Public::PackLane')->get_default_pack_lane();

    isa_ok($result, 'XTracker::Schema::Result::Public::PackLane', 'Got a lane');

}

sub use_default_lane_if_no_match :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    my $config = [{
            pack_lane_id => 6,
            human_name => 'multi_tote_pack_lane_1',
            internal_name => 'DA.PO01.0000.CCTA01NP03',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
    }, {
            pack_lane_id => 3,
            human_name => 'multi_tote_pack_lane_5',
            internal_name => 'DA.PO01.0000.CCTA03NP03',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__DEFAULT ]
    }];

    $plt->reset_and_apply_config($config);

    # A sample when the only lane is a premier multitote?
    # See you in the default lane!
    $plt->create_container('M1', $pt->samples, 1, 1);
    $plt->allocate_container_and_test('M1', 'multi_tote_pack_lane_5', 'No match for lane.. go to default (multi_tote_pack_lane_5)');

}

sub container_fields_filled_in :Tests() {
    my $self = shift;
    my $plt = $self->{'plt'};

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

    my $container = $plt->create_container('M1', $pt->samples, 1, 1);

    $container->discard_changes;
    ok(!defined($container->has_arrived), 'The container which hasnt been allocated has not arrived');
    ok(!$container->routed_at, 'The container which hasnt been allocated does not have a routing_at time');
    ok(!$container->arrived_at, 'The container which hasnt been allocated does not have an arrived at');
    ok(!$container->pack_lane_id, 'The container which hasnt been allocated does not have a pack_lane_id');

    $plt->allocate_container('M1');
    $container->discard_changes;

    ok($container->pack_lane_id, 'The container which has been allocated has a pack_lane_id');
    ok($container->routed_at, 'The container which has been allocated has a routed_at value');
    ok(defined($container->has_arrived), 'The container which has been allocated has a has_arrived value');
    ok(!$container->has_arrived, 'The container which has been allocated has a has_arrived value of false');
    ok(!$container->arrived_at, 'The container which has been allocated does not have an arrived at');

}


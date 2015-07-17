package Test::NAP::Induction;

=head1 NAME

Test::NAP::Induction - Integration test for induction of totes

=head1 DESCRIPTION

Integration test for induction of totes at /Fulfilment/Induction.

Verify there is a list of Containers to induct.

Verify there is an input field which is Green when the induction capacity >
0, otherwise Red.

Verify there is a checkbox indicating "I am in the Cage".

After the user scans a Container, verify a question is asked about whether or
not the Container can be conveyed.

After the Container is inducted, verify the user is presented with an instruction
about what to do with the Container (put on Conveyor, walk to Pack Lane, etc).

#TAGS fulfilment induction packing prl http allocation route dematic

=head1 SEE ALSO

L<Test::NAP::Commissioner::InductToPacking> -- Containers can also be
inducted from the /Fulfilment/Commissioner page (in Packing Exception).

=head1 METHODS

=cut

use NAP::policy "tt", "test", "class";
BEGIN { extends "NAP::Test::Class" }
use Test::XTracker::RunCondition (
    prl_phase => "prl",
);

use MooseX::Params::Validate;
use Test::More;
use Test::More::Prefix qw( test_prefix );

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :allocation_status
    :storage_type
    :physical_place
    :prl
);
use vars qw/$PRL__FULL $PRL__DEMATIC/;
use XT::Data::PRL::PackArea;

use XTracker::Order::Actions::Fulfilment::Commissioner::InductToPacking;
use XTracker::Config::Local "config_var";


use Test::XT::Flow;
use Test::XT::Fixture::Fulfilment::Shipment;
use Test::XT::Data::Container;
use Test::XTracker::Data::PackRouteTests;
use Test::XTracker::Pick::TestScheduler;


BEGIN {

has flow => (
    is => "ro",
    default => sub {
        my $self = shift;
        my $flow = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Feature::AppMessages',
                'Test::XT::Flow::Fulfilment',
            ],
            dbh => $self->schema->storage->dbh,
        );

        $flow->login_with_permissions({
            perms => { $AUTHORISATION_LEVEL__MANAGER => [
                'Customer Care/Customer Search',
                'Customer Care/Order Search',
                'Fulfilment/Selection',
                'Fulfilment/Picking',
                'Fulfilment/Induction',
                'Fulfilment/Packing',
            ]},
            dept => 'Customer Care'
        });

        return $flow;
    }
);

has default_single_tote_fixture => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return Test::XT::Fixture::Fulfilment::Shipment
            ->new({ flow => $self->flow })
            ->with_normal_sla()
            ->with_staged_shipment();
    }
);

has default_multi_tote_fixture => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return Test::XT::Fixture::Fulfilment::Shipment
            ->new({ flow => $self->flow })
            ->with_normal_sla()
            ->with_staged_shipment()
            ->with_shipment_items_moved_into_additional_containers();
    }
);

has restore_induction_capacity_guard =>(
    is      => "ro",
    default => sub { shift->pack_area->get_capacity_guard() },
);

has pack_area => (
    is   => "ro",
    lazy => 1,
    default => sub {
        my $self = shift;
        XT::Data::PRL::PackArea->new({ schema => $self->schema });
    },
);

} # BEGIN

sub single_tote_fixture_with_allocated_dematic_allocation {
    my $self = shift;

    # Create shipment with 3 pids to be picked from Full prl and
    # one from DCD, stage the Full part.

    my $fixture = Test::XT::Fixture::Fulfilment::Shipment
        ->new({
            flow           => $self->flow,
            prl_pid_counts => {'Dematic' => 1, 'Full' => 3},
            channel_name   => "nap",
        })
        ->with_normal_sla()
        ->with_staged_shipment()
        ->with_allocated_product();

    return $fixture;
}

=head2 check_packing_summary_after_induction

=cut

sub check_packing_summary_after_induction :Tests {
    my $self = shift;

    note 'Create Shipment with one allocation in Dematic PRL and another in FUll';
    note 'Stock from Full PRL goes in three containers';
    my $fixture = $self
        ->single_tote_fixture_with_allocated_dematic_allocation
        ->with_shipment_items_moved_into_additional_containers();

    my $flow = $fixture->flow;

    my @container_ids = $fixture->shipment_row->containers->all;

    # Set a Packing Station
    $flow->mech__fulfilment__set_packing_station( $fixture->shipment_row->get_channel->id );

    note 'Go to induction page and submit one of the containers into indicating it is in Cage';
    $flow->flow_mech__fulfilment__induction;
    $flow->flow_mech__fulfilment__induction__check_is_in_cage;
    $flow->flow_mech__fulfilment__induction_submit(
        $container_ids[0]->id->as_barcode
    );
    $flow->flow_mech__fulfilment__induction_answer_submit('no_caged_items');

    note 'Go to Packing and scan Shipment ID';
    $flow->flow_mech__fulfilment__packing;

    note 'Do not worry about erro message: it is not what we are after here';
    $flow->catch_error(
        qr/./,
        'Just make sure that error message is shown',
        flow_mech__fulfilment__packing_submit => ( $fixture->shipment_row->id )
    );

    note 'Capture user info message and check if it indicates'
        .' that all picked containers are in Cage';
    my $app_info_message = $flow->mech->app_info_message;

    foreach my $container_row (@container_ids) {
        my $message_to_check = $container_row->id . ' (Cage)';
        like(
            $app_info_message,
            qr/\Q$message_to_check\E/,
            $container_row->id . ' is marked as one in Cage'
        );
    }
}

sub single_tote_fixture {
    my $self = shift;
    $self->default_single_tote_fixture->with_restaged_shipment();
}

sub multi_tote_fixture {
    my $self = shift;
    $self->default_multi_tote_fixture->with_restaged_shipment();
}

=head2 startup

=cut

sub startup : Tests(startup) {
    my $self = shift;
    $self->SUPER::startup();

    my $pack_route_test = Test::XTracker::Data::PackRouteTests->new();
    $pack_route_test->reapply_config(
        $pack_route_test->like_live_packlane_configuration(),
    );

}

=head2 setup

=cut

sub setup : Tests(setup) {
    my $self = shift;
    test_prefix("");
    $self->SUPER::setup();

    # default to be able to scan things on, reset in tests that need
    # to check things when it's full
    $self->pack_area->induction_capacity(150);
}

=head2 test_scan_container__fail

=cut

sub test_scan_container__fail : Tests() {
    my $self = shift;
    my $fixture = $self->single_tote_fixture;
    my $flow = $fixture->flow;


    test_prefix "Scan malformed Container";
    my $malformed_container_barcode = "MALFORMED_CONTAINER_ID";
    $flow->flow_mech__fulfilment__induction;
    $flow->catch_error(
        qr/^Unrecognized barcode format \($malformed_container_barcode\)/,
        "Malformed Container yields correct error",
        flow_mech__fulfilment__induction_submit => (
            $malformed_container_barcode,
        ),
    );


    my $missing_container_id = Test::XT::Data::Container->get_unique_id();
    $flow->flow_mech__fulfilment__induction;
    $flow->catch_error(
        qr/^Unknown Container \($missing_container_id\)/,
        "Missing Container yields correct error",
        flow_mech__fulfilment__induction_submit => ($missing_container_id),
    );


    my ($empty_container_id)
        = Test::XT::Data::Container->create_new_containers();
    $flow->flow_mech__fulfilment__induction;
    $flow->catch_error(
        qr/^Container $empty_container_id cannot be inducted \(it may have outstanding picks, or it may have already been inducted\)/,
        "Container that can't be inducted yields correct error",
        flow_mech__fulfilment__induction_submit => ($empty_container_id),
    );

}

=head2 capacity_under__can_not_scan

=cut

sub capacity_under__can_not_scan : Tests() {
    my $self = shift;
    my $flow = $self->flow();
    $self->pack_area->induction_capacity(0);

    $flow->flow_mech__fulfilment__induction;
    like($flow->mech->content, qr/can_not_scan/ms, "Scan disabled in form");
}

sub force_induction_url {
    my ($self, $container_id) = @_;
    return XTracker::Order::Actions::Fulfilment::Commissioner::InductToPacking::induction_url(
        $container_id,
    );
}

=head2 capacity_under__scan_anyway__fails

=cut

sub capacity_under__scan_anyway__fails : Tests() {
    my $self = shift;
    my $fixture = $self->single_tote_fixture;
    my $flow = $fixture->flow();

    $self->pack_area->induction_capacity(0);

    my $force_url = $self->force_induction_url( $fixture->picked_container_id );
    my $url = ( $force_url =~ s/\&is_force=1//r );

    note "GET ($url)";
    $flow->mech->get($url);
    like(
        $flow->mech->app_error_message() // "",
        qr/There is no capacity to induct any totes at the moment, please try later/,
        "Correct error message that the is no capacity",
    ) or diag("HTML: " . $flow->mech->content);

}

=head2 capacity_under__scan_with_force__can_be_inducted

=cut

sub capacity_under__scan_with_force__can_be_inducted : Tests() {
    my $self = shift;
    my $fixture = $self->single_tote_fixture;
    my $flow = $fixture->flow();

    $self->pack_area->induction_capacity(150);

    my $force_url = $self->force_induction_url( $fixture->picked_container_id );

    note "GET ($force_url)";
    $flow->mech->get($force_url);
    like(
        $flow->mech->content,
        qr/Can the tote be conveyed/,
        "Question asked, indicating the induction can go ahead",
    ) or diag("HTML: " . $flow->mech->content);
    is(
        $flow->mech->app_error_message(),
        undef,
        "No error message that the is no capacity",
    ) or diag("HTML: " . $flow->mech->content);

}




=head2 qa__at_induction__invalid_answer

=cut

sub qa__at_induction__invalid_answer : Tests() {
    my $self = shift;

    my $fixture = $self->single_tote_fixture;
    my $flow = $fixture->flow;

    my $container_id = $fixture->picked_container_id;
    $flow
        ->flow_mech__fulfilment__induction
        ->flow_mech__fulfilment__induction_submit(
            $container_id->as_barcode,
        );

    $flow->catch_error(
        qr/^\QInternal error: Invalid answer (INVALID)/,
        "Invalid answer gives correct error",
        flow_mech__fulfilment__induction_answer_submit => ("INVALID"),
    );
}


sub _qa__test_answer {
    my ($self, $description, $fixture, $is_in_cage, $is_staged_multi_tote, $dematic_allocation_row, $answer, $expected)
        = validated_list(\@_,
            description            => {},
            fixture                => {},
            is_in_cage             => {},
            is_staged_multi_tote   => {}, # Multiple totes in staging area
            dematic_allocation_row => {},
            answer                 => {},
            expected               => {
                # answers
                # is_message_sent
                # is_inducted
                # user_instruction_rex
            },
        );
    test_prefix $description;


    note "* Setup";

    my $flow = $fixture->flow;

    # Set up fake message queue
    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new("xt_to_prls");

    # Set up known induction_capacity
    my $induction_capacity = 150;
    $self->pack_area->induction_capacity($induction_capacity);



    note "* Run";
    $flow->flow_mech__fulfilment__induction;

    if($is_in_cage) {
        $flow->flow_mech__fulfilment__induction__check_is_in_cage();
    }

    my $picked_container_id = $fixture->picked_container_id;
    $flow->flow_mech__fulfilment__induction_submit(
        $picked_container_id->as_barcode,
    );

    my $mech = $flow->mech;
    my @inducted_container_rows = ( $fixture->picked_container_row );
    if( $is_staged_multi_tote ) {
        my $additional_container_rows = $fixture->additional_container_rows;
        push(@inducted_container_rows, @$additional_container_rows);

        my $other_ids = join(
            ", ",
            sort map { $_->id } @$additional_container_rows,
        );
        like(
            $mech->app_info_message(),
            qr/$other_ids must be inducted together with $picked_container_id/,
            "Correct user instruction to ensure all containers are present",
        ) or diag("HTML: " . $mech->content);

    }

    if($expected->{answers}) {
        eq_or_diff(
            $mech->as_data->{can_be_conveyed_answers},
            $expected->{answers},
            "Page has the answer options",
        );
    }

    if($expected->{answers}) {
        $self->flow->flow_mech__fulfilment__induction_answer_submit($answer);
    }
    $fixture->discard_changes;


    note "* Test";
    like(
        $mech->app_info_message(),
        $expected->{user_instruction_rex},
        "Correct user instruction",
    ) or diag("HTML: " . $mech->content);

    my @expected_messages;
    if ($expected->{is_message_sent}) {
        note "The route messages was sent for the PackLane";
        push(
            @expected_messages,
            (
                map { $self->expected_route_message($_->id) }
                @inducted_container_rows
            ),
        );
    }

    my $picked_container_row = $fixture->picked_container_row;

    # Set the physical place if it's in the Cage
    my $expected_container_physical_place_id = undef;
    if ($is_in_cage) {
        $expected_container_physical_place_id = $PHYSICAL_PLACE__CAGE;
    }
    is(
        $picked_container_row->physical_place_id,
        $expected_container_physical_place_id,
        "The Container.physical_place_id is the expected one ("
            . ( $expected_container_physical_place_id // "")
            . ")",
    );


    note "If inducted, the Allocation status is PICKED,";
    note "    all Containers are routed to their PackLane";
    note "    and the induction_capacity has decreased";
    my $expected_allocation_status_id = $ALLOCATION_STATUS__STAGED;
    if ($expected->{is_inducted}) {
        note "The Allocation Status has changed to Picked";
        $expected_allocation_status_id = $ALLOCATION_STATUS__PICKED;

        for my $container_row (@inducted_container_rows) {
            isnt(
                $container_row->pack_lane_id,
                undef,
                "Container " . $container_row->id . " has a pack_lane_id after routing",
            );

            if( $expected->{is_message_sent}) {
                note "Is inducted, and message is sent ==> on Conveyor";
                is(
                    $container_row->arrived_at,
                    undef,
                    "    and it was routed to Pack Lane...",
                );
                ok(
                    ! $container_row->has_arrived,
                    "    ...but it's not there yet",
                );
            }
            else {
                note "Is inducted, but no message ==> walked over";
                isnt(
                    $container_row->arrived_at,
                    undef,
                    "    and it was walked over to the pack lane...",
                );
                ok(
                    $container_row->has_arrived,
                    "    ...immediately",
                );
            }
        }

        $induction_capacity -= scalar @inducted_container_rows;
    }

    note "Still present in the list of totes?";
    if ($expected->{is_inducted}) {
        for my $container_row ( @inducted_container_rows ) {
            $self->test_container_absent_from_listing( $container_row->id );
        }
    }

    note "Pack Lane assignment";
    if ( $expected->{is_inducted} ) {
        isnt(
            $picked_container_row->pack_lane_id,
            undef,
            "The Container was assigned a Pack Lane",
        );
    }
    else {
        is(
            $picked_container_row->pack_lane_id,
            undef,
            "The Container was not assigned a Pack Lane",
        );
    }
    if($expected->{has_arrived}) {
        ok($picked_container_row->has_arrived, "has_arrived is set");
        ok($picked_container_row->arrived_at, "arrived_at is set");
    }
    else {
        ok( ! $picked_container_row->has_arrived, "has_arrived is not set");
        ok( ! $picked_container_row->arrived_at, "arrived_at is not set");
    }


    my $related_allocation_row = $picked_container_row
        ->shipment_items
        ->search_related("allocation_items")
        ->search_related("allocation")
        ->search({ prl_id => $PRL__FULL})
        ->first;

    is(
        $related_allocation_row->status_id,
        $expected_allocation_status_id,
        "New allocation status is as expected",
    ) or note("Debug: Intermittent test (a) failed again\n");

    is(
        $self->pack_area->induction_capacity(),
        $induction_capacity,
        "The induction_capacity is as expected ($induction_capacity)",
    );

    if ($expected->{is_inducted}) {
        # If we have inducted it, we should've logged the allocation status change
        my $allocation_item_log_row = $related_allocation_row
            ->allocation_items     # the log is done by allocation_item, so when allocation
            ->first                # status is updated we get a row for each item and it
            ->allocation_item_logs # doesn't matter which item's logs we use
            ->search({},{
                'order_by' => 'id desc'
            })->first;             # get the latest log row
        ok($allocation_item_log_row, "At least one allocation_item_log row exists");
        is($allocation_item_log_row->allocation_status_id, $expected_allocation_status_id,
            "Latest log row contains the correct allocation status");
    }


    # After inducting, maybe run the Pick::Scheduler to trigger the
    # DCD pick
    if ($dematic_allocation_row) {
        if( (config_var("PickScheduler", "version") // 0) == 2 ) {
            my $pick_scheduler = Test::XTracker::Pick::TestScheduler->new(
                # msg_factory => $xt_to_prls,
                test_shipment_ids => [ $dematic_allocation_row->shipment->id ],
                packing_remaining_capacity    => 100, # Plenty of space
                mock_sysconfig_parameter => {
                    dcd_picking_total_capacity => 100, # Plenty of pick capacity
                    full_induction_capacity        => $induction_capacity,
                }
            );
            $pick_scheduler->schedule_allocations();
        }
        $dematic_allocation_row->discard_changes();

        note "The Dematic pick message was sent";
        push(
            @expected_messages,
            {
                type    => "pick",
                details => {
                    allocation_id    => $dematic_allocation_row->id,
                    "x-prl-specific" => {
                        shipment_id => $fixture->shipment_row->id,
                    },
                },
            },
        );

        is(
            $dematic_allocation_row->status_id,
            $ALLOCATION_STATUS__PICKING,
            "Dematic allocation status is now in PICKING",
        ) or note("Debug: Intermittent test (b) failed again\n");
    }

    @expected_messages and $xt_to_prls->expect_messages({
        messages => \@expected_messages,
    });


    test_prefix("");
}

sub test_container_absent_from_listing {
    my ($self, $container_id) = @_;
    my $mech = $self->flow->mech();

    my $containers_ready_for_packing
        = $mech->as_data->{containers_ready_for_packing} // [];

    my $found_contaner_count =
        grep { $_ eq $container_id }
        map  { $_->{Container} }
        @{$containers_ready_for_packing};
    is(
        $found_contaner_count,
        0,
        "Inducted Container ($container_id) is gone from listing",
    );

}

sub test_shipment_present_in_packing_list {
    my ($self, $shipment) = @_;

    ok(
        $self->is_shipment_in_packing_list($shipment),
        "Shipment [".$shipment->id."] is in packing list",
    );
}

sub test_shipment_absent_from_packing_list {
    my ($self, $shipment) = @_;

    ok(
        !$self->is_shipment_in_packing_list($shipment),
        "Shipment [".$shipment->id."] is not in packing list",
    );

}

sub is_shipment_in_packing_list {

    my ($self, $shipment) = @_;

    my $mech = $self->flow->mech();

    my $channel_prefix = $shipment->order->channel->business->config_section;
    my $shipments_ready_for_packing
        = $mech->as_data->{"shipments_ready_for_packing_$channel_prefix"} // [];

    my $found_shipment_count =
        grep { $_ eq $shipment->id }
        map  { $_->{"Shipment Number"}->{"value"} }
        @{$shipments_ready_for_packing};

    return !!$found_shipment_count;
}


sub expected_route_message {
    my ($self, $container_id) = @_;

    return {
        type    => "route_request",
        details => {
            container_id => "$container_id",
            # ignore the exact destination, it might vary, and
            # it's tested indirectly by the user message
            # anyway
        },
    };
}

=head2 qa__at_induction__single_tote__yes

=cut

sub qa__at_induction__single_tote__yes : Tests() {
    my $self = shift;
    $self->_qa__test_answer({
        description            => "Induction, Single: yes",
        fixture                => $self->single_tote_fixture,
        is_in_cage             => 0,
        is_staged_multi_tote   => 0,
        dematic_allocation_row => undef,
        answer                 => "yes",
        expected               => {
            answers => [
                "Yes - all items fit in tote",
                "No - over height items present",
            ],
            is_message_sent      => 1,
            is_inducted          => 1,
            has_arrived          => 0,
            user_instruction_rex => qr/^Please place tote \w+ onto the conveyor/,
        },
    });
}

=head2 qa__at_induction__single_tote__no_overheight

=cut

sub qa__at_induction__single_tote__no_overheight : Tests() {
    my $self = shift;
    my $container_id = $self->single_tote_fixture->picked_container_id();
    $self->_qa__test_answer({
        description            => "Induction, Single: no, over height",
        fixture                => $self->single_tote_fixture,
        answer                 => "no_over_height",
        is_in_cage             => 0,
        is_staged_multi_tote   => 0,
        dematic_allocation_row => undef,
        expected               => {
            answers => [
                "Yes - all items fit in tote",
                "No - over height items present",
            ],
            is_message_sent      => 0,
            is_inducted          => 1,
            has_arrived          => 1,
            user_instruction_rex => qr/Please take tote $container_id to pack lane \d+/,
        },
    });

}

=head2 qa__in_cage__single_tote__default_answer_in_cage

=cut

sub qa__in_cage__single_tote__default_answer_in_cage : Tests() {
    my $self = shift;
    my $container_id = $self->single_tote_fixture->picked_container_id();
    $self->_qa__test_answer({
        description            => "In Cage, Single: default=no, in cage",
        fixture                => $self->single_tote_fixture,
        is_staged_multi_tote   => 0,
        dematic_allocation_row => undef,
        is_in_cage             => 1,
        answer                 => undef,
        expected               => {
            answers              => undef,
            is_message_sent      => 0,
            is_inducted          => 1,
            has_arrived          => 1,
            user_instruction_rex => qr/Please take tote $container_id to pack lane \d+/,
        },
    });

}

=head2 qa__at_induction__multi_tote__yes

=cut

sub qa__at_induction__multi_tote__yes : Tests() {
    my $self = shift;

    $self->_qa__test_answer({
        description            => "Induction, Multi: yes",
        fixture                => $self->multi_tote_fixture,
        is_in_cage             => 0,
        is_staged_multi_tote   => 1,
        dematic_allocation_row => undef,
        answer                 => "yes",
        expected               => {
            answers => [
                "Yes - all items fit in tote, all totes present",
                "No - over height items present",
                "No - all totes not present",
            ],
            is_message_sent      => 1,
            is_inducted          => 1,
            has_arrived          => 0,
            user_instruction_rex => qr/^Please place tote \w+ AND \w+, \w+ onto the conveyor/,
        },
    });
}

=head2 qa__in_cage__multi_tote__no_in_cage

At the induction point, this is a default answer but in this case, in the Cage
it's not.

=cut

sub qa__in_cage__multi_tote__no_in_cage : Tests() {
    my $self = shift;
    my $container_id = $self->multi_tote_fixture->picked_container_id();
    $self->_qa__test_answer({
        description            => "In Cage, Multi: no, caged items",
        fixture                => $self->multi_tote_fixture,
        is_staged_multi_tote   => 1,
        dematic_allocation_row => undef,
        is_in_cage             => 1,
        answer                 => "no_caged_items",
        expected               => {
            answers => [
                "No - contains caged items",
                "No - all totes not present",
            ],
            is_message_sent      => 0,
            is_inducted          => 1,
            has_arrived          => 1,
            user_instruction_rex => qr/Please take tote \w+ AND \w+, \w+ to multi tote pack lane \d+/,
        },
    });

}

=head2 qa__at_induction__multi_tote__all_not_present

=cut

sub qa__at_induction__multi_tote__all_not_present : Tests() {
    my $self = shift;
    $self->_qa__test_answer({
        description            => "At Induction, Multi: no, all containers not present",
        fixture                => $self->multi_tote_fixture,
        is_staged_multi_tote   => 1,
        dematic_allocation_row => undef,
        is_in_cage             => 0,
        answer                 => "no_all_totes_not_present",
        expected               => {
            answers => [
                "Yes - all items fit in tote, all totes present",
                "No - over height items present",
                "No - all totes not present",
            ],
            is_message_sent      => 0,
            is_inducted          => 0,
            has_arrived          => 0,
            user_instruction_rex => qr/\QDon't induct this container now. Wait until all containers are present./,
        },
    });

}

=head2 qa__single_staged_tote__dematic_prl_unpicked

=cut

sub qa__single_staged_tote__dematic_prl_unpicked : Tests() {
    my $self = shift;

    my $fixture = $self->single_tote_fixture_with_allocated_dematic_allocation;

    $self->_qa__test_answer({
        description            => "Multi-PRL, unpicked Dematic",
        fixture                => $fixture,
        is_in_cage             => 0,
        is_staged_multi_tote   => 0,
        dematic_allocation_row => $fixture->dematic_allocation_row,
        answer                 => "yes",
        expected               => {
            answers => [
                "Yes - all items fit in tote",
                "No - over height items present",
            ],
            is_message_sent      => 1,
            is_inducted          => 1,
            has_arrived          => 0,
            user_instruction_rex => qr/^Please place tote \w+ onto the conveyor/,
        },
    });
}

=head2 qa__in_cage__single_staged_tote__dematic_prl_unpicked

=cut

sub qa__in_cage__single_staged_tote__dematic_prl_unpicked : Tests() {
    my $self = shift;

    my $fixture = $self->single_tote_fixture_with_allocated_dematic_allocation;

    $self->_qa__test_answer({
        description            => "In Cage, Multi-PRL, unpicked Dematic",
        fixture                => $fixture,
        is_in_cage             => 1,
        is_staged_multi_tote   => 0,
        dematic_allocation_row => $fixture->dematic_allocation_row,
        answer                 => "yes",
        expected               => {
            answers              => undef,
            is_message_sent      => 0,
            is_inducted          => 1,
            has_arrived          => 1,
            # If in Cage, and unpicked Dematic totes, tell User to
            # wait for them
            user_instruction_rex => qr/^Shipment incomplete, please retain tote \w+ in the Cage ready to be fetched to/,
        },
    });
}

=head2 qa__at_induction__multi_tote__dematic_prl_unpicked__yes

=cut

sub qa__at_induction__multi_tote__dematic_prl_unpicked__yes : Tests() {
    my $self = shift;
    my $fixture = $self
        ->single_tote_fixture_with_allocated_dematic_allocation
        ->with_shipment_items_moved_into_additional_containers();
    $self->_qa__test_answer({
        description            => "Induction, Multi, with allocated Dematic: yes",
        fixture                => $fixture,
        is_in_cage             => 0,
        is_staged_multi_tote   => 1,
        dematic_allocation_row => $fixture->dematic_allocation_row,
        answer                 => "yes",
        expected               => {
            answers => [
                "Yes - all items fit in tote, all totes present",
                "No - over height items present",
                "No - all totes not present",
            ],
            is_message_sent      => 1,
            is_inducted          => 1,
            has_arrived          => 0,
            user_instruction_rex => qr/^Please place tote \w+ AND \w+, \w+ onto the conveyor/,
        },
    });
}

=head2 qa__cancelled_on_hold__goes_to_packing_exception

=cut

sub qa__cancelled_on_hold__goes_to_packing_exception : Tests() {
    my $self = shift;
    my $fixture = Test::XT::Fixture::Fulfilment::Shipment
        ->new({ flow => $self->flow })
        ->with_staged_shipment()
        ->with_shipment_on_hold();

    $self->_qa__test_answer({
        description            => "Shipment on Hold, goes to PE",
        fixture                => $fixture,
        is_in_cage             => 0,
        is_staged_multi_tote   => 0,
        dematic_allocation_row => undef,
        answer                 => "yes",
        expected               => {
            answers => [
                "Yes - all items fit in tote",
                "No - over height items present",
            ],
            is_message_sent      => 1,
            is_inducted          => 1,
            has_arrived          => 0,
            user_instruction_rex => qr/^Please place tote \w+ onto the conveyor/,
        },
    });
}

=head2 check_packing_list

Shipments shouldn't appear on the packing list if they have an allocation
waiting to be inducted.

=cut

sub check_packing_list :Tests {
    my $self = shift;

    my $fixture = $self->single_tote_fixture;

    my $flow = $fixture->flow;

    my ($container) = $fixture->shipment_row->containers->all;

    # Set a Packing Station
    $flow->mech__fulfilment__set_packing_station( $fixture->shipment_row->get_channel->id );

    note 'Allocation is still staged so the shipment should not appear on the packing page';
    $flow->flow_mech__fulfilment__packing;
    $self->test_shipment_absent_from_packing_list( $fixture->shipment_row);

    note 'Go to induction page and submit the container';
    $flow->flow_mech__fulfilment__induction;
    $flow->flow_mech__fulfilment__induction_submit(
        $container->id->as_barcode
    );
    $flow->flow_mech__fulfilment__induction_answer_submit('yes');

    note 'Shipment should now appear on the packing page';
    $flow->flow_mech__fulfilment__packing;
    $self->test_shipment_present_in_packing_list( $fixture->shipment_row);
}

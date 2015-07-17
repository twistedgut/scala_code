package Test::XTracker::Schema::Result::Public::Allocation;

=head1 NAME

Test::XTracker::Schema::Result::Public::Allocation - Unit tests for
XTracker::Schema::Result::Public::Allocation

=cut

use NAP::policy 'class', 'test', 'tt';
use FindBin::libs;
use Test::XTracker::LoadTestConfig;
use MooseX::Params::Validate;

BEGIN {
    with 'Test::Role::WithDeliverResponse';
    extends 'NAP::Test::Class';
}

use Test::XTracker::RunCondition
    prl_phase => 'prl',
    export => [qw( $prl_rollout_phase )];

use XTracker::Config::Local qw( config_var );
use XTracker::Constants qw(
    :application
    :prl_type
);
use XTracker::Constants::FromDB qw(
    :allocation_item_status
    :allocation_status
    :prl
    :prl_delivery_destination
    :shipment_item_status
    :shipment_status
    :storage_type
);
use vars qw/
    $PRL__GOH
    $PRL_DELIVERY_DESTINATION__GOH_DIRECT
    $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
/;

use XTracker::Schema::Result::Public::Allocation;

use Test::XT::Data;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::XT::Fixture::Fulfilment::Shipment;

use Test::XT::Fixture::Fulfilment::Shipment;

sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{msg_factory} = Test::XTracker::MessageQueue->new;

    $self->{data_helper} = Test::XT::Data->new_with_traits(
        traits  => [qw/Test::XT::Data::Order Test::Role::DBSamples/]
    );
}

sub setup : Test(setup) {
    my $self = shift;
    $self->SUPER::setup;

    my %product_storage_type = (
        full_product => $PRODUCT_STORAGE_TYPE__FLAT,
        dms_product  => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
        goh_product  => $PRODUCT_STORAGE_TYPE__HANGING,
    );
    @{$self}{(keys %product_storage_type)} = map {
        Test::XTracker::Data->create_test_products({ storage_type_id => $_ })
    } values %product_storage_type;
}

sub test_allocate_pack_space : Tests() {
    my $self = shift;

    SKIP: {
        skip 'Only in PRL phase 2+', 1 unless $prl_rollout_phase >= 2;

        note "*** Setup";
        my $fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
            pids => [ $self->{goh_product} ],
        });
        my $allocation_row = $fixture->shipment_row->allocations->first();

        note "* Setup allocation status";
        $allocation_row->update({
            status_id => $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE,
        });

        note "* Pretend allocation was completely short picked";
        $allocation_row->allocation_items->update({
            status_id => $ALLOCATION_ITEM_STATUS__SHORT,
        });

        my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

        note "*** Run with short picked items";
        $allocation_row->allocate_pack_space();
        $allocation_row->discard_changes();

        note "*** Test";
        is($allocation_row->status_id, $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE,
           "Allocation status unchanged");

        # Allocating pack space shouldn't send a prepare message if no items were picked
        $xt_to_prl->expect_no_messages();

        note "* Now pretend allocation was all picked successfully";
        $allocation_row->allocation_items->update({
            status_id => $ALLOCATION_ITEM_STATUS__PICKED,
        });

        note "*** Run with successfully picked items";
        $allocation_row->allocate_pack_space();
        $allocation_row->discard_changes();

        note "*** Test";
        is($allocation_row->status_id, $ALLOCATION_STATUS__PREPARING,
           "New status ok");

        # Allocating pack space (in the GOH PRL) should send a prepare message
        $xt_to_prl->expect_messages({
            messages => [ {
                type    => 'prepare',
                path    => $allocation_row->prl->amq_queue,
                details => {
                    allocation_id => $allocation_row->id,
                    destination   =>
                        $allocation_row->get_prl_delivery_destination->
                            message_name,
                },
            } ],
        });

        note "*** Run, test";
        my $id = $allocation_row->id;
        throws_ok(
            sub { $allocation_row->allocate_pack_space() },
            qr/Can't allocate pack space, allocation \($id\) is in status \(preparing\), not \(allocating_pack_space\)/,
            "Correct exception"
        );
    }
}

=head2 test_pick_complete

=cut

sub test_pick_complete : Tests() {
    my $self = shift;

    for (
        {
            name => 'pick complete full PRL',
            setup => {
                product                   => $self->{full_product},
                allocation_item_status_id => $ALLOCATION_ITEM_STATUS__PICKED,
                shipment_item_status_id   => $SHIPMENT_ITEM_STATUS__PICKED,
            },
            expected => {
                allocation_status_id      => $ALLOCATION_STATUS__STAGED,
                shipment_status_id        => $SHIPMENT_STATUS__PROCESSING,
                allocation_item_status_id => $ALLOCATION_ITEM_STATUS__PICKED,
                shipment_item_status_id   => $SHIPMENT_ITEM_STATUS__PICKED,
            },
        },
        {
            name => 'pick complete Dematic',
            setup => {
                product                   => $self->{dms_product},
                allocation_item_status_id => $ALLOCATION_ITEM_STATUS__PICKED,
                shipment_item_status_id   => $SHIPMENT_ITEM_STATUS__PICKED,
            },
            expected => {
                allocation_status_id      => $ALLOCATION_STATUS__PICKED,
                shipment_status_id        => $SHIPMENT_STATUS__PROCESSING,
                allocation_item_status_id => $ALLOCATION_ITEM_STATUS__PICKED,
                shipment_item_status_id   => $SHIPMENT_ITEM_STATUS__PICKED,
            },
        },
        {
            name => 'short pick customer shipment',
            setup => {
                product                   => $self->{full_product},
                allocation_item_status_id => $ALLOCATION_ITEM_STATUS__PICKING,
            },
            expected => {
                allocation_status_id      => $ALLOCATION_STATUS__STAGED,
                shipment_status_id        => $SHIPMENT_STATUS__HOLD,
                allocation_item_status_id => $ALLOCATION_ITEM_STATUS__SHORT,
                shipment_item_status_id   => $SHIPMENT_ITEM_STATUS__NEW,
            },
        },
        {
            name => 'short pick cancelled-during-picking customer shipment',
            setup => {
                product                   => $self->{full_product},
                allocation_item_status_id => $ALLOCATION_ITEM_STATUS__PICKING,
                shipment_status_id        => $SHIPMENT_STATUS__CANCELLED,
                shipment_item_status_id   => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
            },
            expected => {
                allocation_status_id      => $ALLOCATION_STATUS__STAGED,
                shipment_status_id        => $SHIPMENT_STATUS__CANCELLED,
                allocation_item_status_id => $ALLOCATION_ITEM_STATUS__SHORT,
                shipment_item_status_id   => $SHIPMENT_ITEM_STATUS__CANCELLED
            },
        },
        {
            name => 'short pick sample shipment',
            setup => {
                product                   => $self->{full_product},
                allocation_item_status_id => $ALLOCATION_ITEM_STATUS__PICKING,
                is_sample => 1,
            },
            expected => {
                allocation_status_id      => $ALLOCATION_STATUS__STAGED,
                shipment_status_id        => $SHIPMENT_STATUS__CANCELLED,
                allocation_item_status_id => $ALLOCATION_ITEM_STATUS__SHORT,
                shipment_item_status_id   => $SHIPMENT_ITEM_STATUS__CANCELLED,
            },
        },
    ) {
        my ( $name, $setup, $expected ) = @{$_}{qw/name setup expected/};
        subtest $name => sub {
            # Create our allocation
            my $allocation
                = $self->_create_allocation(@{$setup}{qw/product is_sample/});

            $allocation->allocation_items->update({
                status_id => $setup->{allocation_item_status_id}
            });

            # We only set the shipment item status to 'picked' if we need to
            # 'fake' a pick message (the message probably does more but it
            # doesn't concern this tset)
            $allocation->allocation_items->related_resultset('shipment_item')->update({
                shipment_item_status_id => $setup->{shipment_item_status_id}
            }) if $setup->{shipment_item_status_id};
            # Might want the shipment to be in a different status too
            $allocation->shipment->update({
                shipment_status_id => $setup->{shipment_status_id}
            }) if $setup->{shipment_status_id};

            # Run the method we're testing
            $allocation->pick_complete($APPLICATION_OPERATOR_ID);

            # Check our expected results
            my $schema = $self->schema;
            my $expected_allocation_status = $schema
                ->resultset('Public::AllocationStatus')
                ->find($expected->{allocation_status_id});
            is( $allocation->status->status,
                $expected_allocation_status->status,
                'allocation status ok' );

            my $expected_shipment_status = $schema
                ->resultset('Public::ShipmentStatus')
                ->find($expected->{shipment_status_id});
            is( $allocation->shipment->discard_changes->shipment_status->status,
                $expected_shipment_status->status,
                'shipment status ok' );

            # Coder laziness alert: if we extend this test to cover
            # multiple-item allocations the following two tests will need more
            # work
            my $expected_allocation_item_status = $schema
                ->resultset('Public::AllocationItemStatus')
                ->find($expected->{allocation_item_status_id});
            is( $allocation->allocation_items->single->status->status,
                $expected_allocation_item_status->status,
                'allocation item status ok' );

            my $expected_shipment_item_status = $schema
                ->resultset('Public::ShipmentItemStatus')
                ->find($expected->{shipment_item_status_id});
            is( $allocation->allocation_items->single->shipment_item->shipment_item_status->status,
                $expected_shipment_item_status->status,
                'shipment item status ok' );
        };
    }
}

sub _create_allocation {
    my ( $self, $product, $is_sample ) = @_;

    my $data_helper = $self->{data_helper};

    # Create an allocation for a sample shipment if that's what we asked for
    return $data_helper->db__samples__create_shipment({
        variant_id => $product->variants->slice(0,0)->single->id,
    })->allocations->single if $is_sample;

    # Otherwise create an allocation for a customer shipment
    return $data_helper
        ->selected_order( products => [$product] )
        ->{order_object}
        ->get_standard_class_shipment
        ->allocations
        ->single;
}

sub test_pick : Tests() {
    my ($self) = @_;

    my $data_helper = $self->{data_helper};

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

    # Add a test for 'requested' allocations and make sure they croak too
    for (
        [ allocated => 'new_order' ],
        [ picking   => 'selected_order' ],
        [ staged    => 'picked_order', { with_staged_allocations => 1 } ],
        [ picked    => 'picked_order' ],
    ) {
        my ( $allocation_status, $create_method, $create_method_args ) = @$_;
        subtest "test calling 'pick' on an allocation with status of $allocation_status" => sub {
            my $shipment = $data_helper
                ->$create_method( products => [$self->{full_product}], %{$create_method_args||{}} )
                ->{order_object}
                ->get_standard_class_shipment;
            my $allocation = $shipment->allocations->single;
            $xt_to_prl->expect_messages({
                messages => [
                    { '@type' => 'allocate', details => { allocation_id => $allocation->id }, }
                ],
            });

            # Trying to 'pick' allocations with a state other than 'allocated' should croak
            if ( $allocation_status ne 'allocated' ) {
                throws_ok(
                    sub { $allocation->pick($self->{msg_factory}, $APPLICATION_OPERATOR_ID ) },
                    qr{Allocation @{[$allocation->id]}},
                    "picking an allocation with a status of $allocation_status should croak"
                );
                return;
            }
            lives_ok(
                sub { $allocation->pick($self->{msg_factory}, $APPLICATION_OPERATOR_ID) },
                'picking an allocation should live'
            );

            # Check the expected output
            $xt_to_prl->expect_messages({
                messages => [
                    { '@type' => 'pick', details => { allocation_id => $allocation->id }, },
                ],
            });
            ok( $allocation->is_picking,
                sprintf 'allocation %i should have a status of picking', $allocation->id
            ) or diag sprintf q{... but has a status of '%s'}, $allocation->status->status;

            my $allocation_item = $allocation->allocation_items->single;
            ok( $allocation_item->is_picking,
                sprintf 'allocation item %i should have a status of picking', $allocation_item->id
            ) or diag sprintf q{... but has a status of '%s'}, $allocation_item->status->status;

            my $shipment_item = $allocation_item->shipment_item;
            ok( $shipment_item->is_selected,
                sprintf 'shipment item %i should have a status of selected', $shipment_item->id
            ) or diag sprintf q{... but has a status of '%s'}, $shipment_item->shipment_item_status->status;
        };
    }
}

sub test_mark_as_delivered :Tests() {
    my ($self) = @_;

    note "Create shipment with hanging product";
    my $shipment = $self->{data_helper}
        ->picked_order( products => [$self->{goh_product}] )
        ->{order_object}
        ->get_standard_class_shipment;
    my $allocation = $shipment->allocations->single;

    my $message_data = $self->deliver_response_payload(
        $allocation,
        { destination_id => $PRL_DELIVERY_DESTINATION__GOH_DIRECT }
    );

    note "try to mark as delivered before it's ready";
    throws_ok(
        sub { $allocation->mark_as_delivered($message_data, $APPLICATION_OPERATOR_ID) },
        qr{Allocation @{[$allocation->id]} cannot be marked as Delivered - status has to be 'Delivering'},
        "mark_as_delivered dies when the allocation is not yet ready"
    );
    note "update the allocation to be in the correct status to mark as delivered";
    $allocation->update({
        'status_id' => $ALLOCATION_STATUS__DELIVERING,
    });

    lives_ok(
        sub { $allocation->mark_as_delivered($message_data, $APPLICATION_OPERATOR_ID) },
        "mark_as_delivered lives when the allocation is in status Delivering"
    );
    is (
        $allocation->status_id, $ALLOCATION_STATUS__DELIVERED,
        "allocation status updated to Delivered"
    );

    foreach my $allocation_item ($allocation->allocation_items) {
        ok ($allocation_item->delivered_at, "delivered_at has been set");
        is (
            $allocation_item->actual_prl_delivery_destination_id,
            $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
            "actual_prl_delivery_destination_id has been set correctly"
        );
    }

    note "try to mark as delivered again";
    throws_ok(
        sub { $allocation->mark_as_delivered($message_data, $APPLICATION_OPERATOR_ID) },
        qr{Allocation @{[$allocation->id]} cannot be marked as Delivered - status has to be 'Delivering'},
        "mark_as_delivered dies when the allocation has already been delivered"
    );

}

sub test_prl_for_integration : Tests {
    my $self = shift;

    # Can't use runcondition for this because that applies to the whole class,
    # but integration only happens in PRL phase 2, and there won't be a GOH
    # PRL until then, so don't test if phase is still 1.
    return ok(1) unless (config_var('PRL', 'rollout_phase') >=2);

    # We should be able to integrate DCD and GOH allocations,
    # but only when all conditions are met.

    note "Test that the GOH allocation is in the right status";
    for (
        [ $ALLOCATION_STATUS__PREPARING, $PRL__GOH ],
        [ $ALLOCATION_STATUS__PREPARED , $PRL__GOH ],
        [ $ALLOCATION_STATUS__PICKED   , undef ],
    ) {
        my ( $goh_allocation_status, $should_be_integrated_with ) = @$_;
        my $fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
            prl_pid_counts => {
                'Dematic' => 1,
                'GOH'     => 1,
            },
        })->with_picked_shipment;
        $fixture->goh_allocation_row->update({
            status_id => $goh_allocation_status,
        });
        if ($should_be_integrated_with) {
            is (
                $fixture->dematic_allocation_row->prl_for_integration->id,
                $should_be_integrated_with,
                sprintf(
                    "DCD allocation can be integrated with GOH allocation in status %s",
                    $fixture->goh_allocation_row->status->status
                )
            );
        } else {
            is (
                $fixture->dematic_allocation_row->prl_for_integration,
                undef,
                sprintf(
                    "DCD allocation cannot be integrated with GOH allocation in status %s",
                    $fixture->goh_allocation_row->status->status
                )
            );
        }
    }

    note "Test that the DCD allocation has no unpicked items";
    my $dcd_and_goh_fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            'Dematic' => 2,
            'GOH'     => 1,
        },
    })->with_picked_shipment->with_prepared_goh_allocation;

    note "If the DCD part is all picked, it can be integrated";
    is ($dcd_and_goh_fixture->dematic_allocation_row->prl_for_integration->id, $PRL__GOH,
        "Fully picked DCD allocation can be integrated");
    note "But if we pretend one item hasn't been picked yet, it can't be integrated";
    $dcd_and_goh_fixture->dematic_allocation_row->allocation_items->first->update({
        status_id => $ALLOCATION_ITEM_STATUS__PICKING,
    });
    is ($dcd_and_goh_fixture->dematic_allocation_row->prl_for_integration, undef,
        "DCD allocation can't be integrated if one item is still in picking");

    note "Test that we won't try to integrate a Full PRL allocation";
    my $full_and_goh_fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            'Full' => 1,
            'GOH'  => 1,
        },
    })->with_picked_shipment->with_prepared_goh_allocation;
    is ($full_and_goh_fixture->full_allocation_row->prl_for_integration, undef,
        "Full allocation can't be integrated");

    note "Test that a DCD allocation that's part of a many-prl shipment can still be integrated";
    my $mixed_fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            'Dematic' => 1,
            'Full'    => 1,
            'GOH'     => 1,
        },
    })->with_picked_shipment->with_prepared_goh_allocation;
    is ($mixed_fixture->dematic_allocation_row->prl_for_integration->id, $PRL__GOH,
        "DCD allocation with sibling Full and GOH allocations can be integrated");

}

=head2 test_maybe_send_deliver_from_pick_complete

For mixed GOH and DCD shipments, we should sometimes send deliver for the GOH
allocation when we get pick_complete for the DCD allocation. We should only
send it if the DCD allocation was short picked, and only if the GOH allocation
is already in Prepared status. In all other scenarios, deliver should be sent
either when we get the route_response for the DCD container arriving at
integration, or when we get prepare_response for the GOH allocation.

=cut

sub test_maybe_send_deliver_from_pick_complete : Tests {
    my $self = shift;

    # Can't use runcondition for this because that applies to the whole class,
    # but integration only happens in PRL phase 2, and there won't be a GOH
    # PRL until then, so don't test if phase is still 1.
    return ok(1) unless (config_var('PRL', 'rollout_phase') >=2);

    for (
        [ $ALLOCATION_STATUS__ALLOCATING_PACK_SPACE, 0 ],
        [ $ALLOCATION_STATUS__PREPARING            , 0 ],
        [ $ALLOCATION_STATUS__PREPARED             , 1 ],
        [ $ALLOCATION_STATUS__PICKED               , 0 ],
    ) {
        my ( $goh_allocation_status, $should_send_deliver ) = @$_;

        note "Set up mixed shipment";
        my $fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
            prl_pid_counts => {
                'Dematic' => 1,
                'GOH'     => 1,
            },
        })->with_prepared_goh_allocation;

        note "DCD items have not yet been picked";
        $fixture->dematic_allocation_row->update({
            'status_id' => $ALLOCATION_STATUS__PICKING
        });
        $fixture->dematic_allocation_row->allocation_items->update({
            'status_id' => $ALLOCATION_ITEM_STATUS__PICKING
        });
        $fixture->goh_allocation_row->update({
            'status_id' => $goh_allocation_status
        });
        $fixture->goh_allocation_row->allocation_items->update({
        'status_id' => $ALLOCATION_ITEM_STATUS__PICKED
        });

        note "Start monitoring messages";
        my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

        note "Call pick_complete on the DCD allocation, and then call maybe_send_deliver_from_pick_complete";
        $fixture->dematic_allocation_row->pick_complete($APPLICATION_OPERATOR_ID);
        $fixture->dematic_allocation_row->maybe_send_deliver_from_pick_complete($APPLICATION_OPERATOR_ID);

        note "Check that allocation statuses and sent messages are correct";
        $fixture->dematic_allocation_row->discard_changes;
        $fixture->goh_allocation_row->discard_changes;
        is ($fixture->dematic_allocation_row->status_id, $ALLOCATION_STATUS__PICKED,
            "DCD allocation is in Picked status");

        if ($should_send_deliver) {
            note "Check that we sent deliver for the GOH allocation";
            is ($fixture->goh_allocation_row->status_id, $ALLOCATION_STATUS__DELIVERING,
                "GOH allocation is in Delivering status");
            $xt_to_prl->expect_messages({
                messages => [ {
                    type    => 'deliver',
                    path    => $fixture->goh_allocation_row->prl->amq_queue,
                    details => { allocation_id => $fixture->goh_allocation_row->id },
                } ],
            });
        } else {
            note "Check that we didn't send deliver for the GOH allocation";
            is ($fixture->goh_allocation_row->status_id, $goh_allocation_status,
                "GOH allocation is still in same status");
            $xt_to_prl->expect_no_messages();
        }
    }

}


sub get_prl_delivery_destination : Tests {
    my $self = shift;

    SKIP: {
        skip 'Only in PRL phase 2+', 4 unless $prl_rollout_phase >= 2;

        note "Test that a GOH-only shipment is sent to the direct lane";
        my $goh_shipment = $self->get_shipment({
            create_method => 'selected_order',
            products      => [ $self->{goh_product} ],
        });

        my $goh_allocation = $goh_shipment->allocations->first;

        ok(my $goh_destination = $goh_allocation->get_prl_delivery_destination,
           'Got a PRL delivery destination');
        isa_ok($goh_destination,
               'XTracker::Schema::Result::Public::PrlDeliveryDestination');
        is($goh_destination->id, $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
           'PRL delivery destination is correct');

        my $dms_shipment = $self->get_shipment({
            create_method => 'selected_order',
            products      => [ $self->{dms_product} ]
        });

        my $dms_allocation = $dms_shipment->allocations->first;

        note "Test that a non-GOH allocation has no delivery destination";
        is($dms_allocation->get_prl_delivery_destination, undef,
           'PRL delivery destination is correctly undefined');

        note "Test that a mixed GOH+DCD shipment sends the GOH allocation to integration";
        my $mixed_shipment = $self->get_shipment({
            create_method => 'selected_order',
            products => [ $self->{dms_product}, $self->{goh_product} ]
        });

        # Sanity check - we should have one GOH and one DCD allocation
        is ($mixed_shipment->allocations->count, 2, "Shipment now has 2 allocations");

        my $mixed_goh_allocation;
        foreach my $allocation ($mixed_shipment->allocations) {
            next unless $allocation->prl->id == $PRL__GOH;
            ok(my $destination = $allocation->get_prl_delivery_destination,
               'Got a PRL delivery destination');
            is($destination->id, $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
               'PRL delivery destination is correct');
            $mixed_goh_allocation = $allocation;
        }

        note "Pick everything";
        $_->update({status_id => $ALLOCATION_STATUS__PICKED})
            foreach $mixed_shipment->allocations;
        $_->update({status_id => $ALLOCATION_ITEM_STATUS__PICKED})
            foreach $mixed_shipment->shipment_items->related_resultset('allocation_items');
        $_->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED})
            foreach $mixed_shipment->shipment_items;

        note "Pretend that the GOH item in the mixed GOH+DCD shipment is discovered to be faulty, and so a replacement is required";
        # Set the shipment item status for the GOH item back to new, and allocate the shipment again
        $mixed_goh_allocation->allocation_items->first->shipment_item->update({
            'shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__NEW,
        });
        $mixed_shipment->allocate({operator_id => $APPLICATION_OPERATOR_ID});

        # We should now have 3 allocations - the original 2, and a new GOH allocation for the replacement
        is ($mixed_shipment->allocations->count, 3, "Shipment now has 3 allocations");

        my $new_goh_allocation;
        foreach my $allocation ($mixed_shipment->allocations) {
            next unless $allocation->prl->id == $PRL__GOH;
            next if ($allocation->id == $mixed_goh_allocation->id); # Don't count the old one
            $new_goh_allocation = $allocation;
        }
        ok ($new_goh_allocation, "We have a new GOH allocation");

        note "Test that the new GOH allocation will be sent to the direct lane";
        ok(my $new_goh_destination = $new_goh_allocation->get_prl_delivery_destination,
           'Got a PRL delivery destination');
        is($new_goh_destination->id, $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
           'PRL delivery destination is correct');


    }
}

sub send_prepare_message : Tests {
    my $self = shift;

    SKIP: {
        skip 'Only in PRL phase 2+', 4 unless $prl_rollout_phase >= 2;

        my $allocation = $self->get_allocation;

        $self->test_sending_message({
            allocation   => $allocation,
            message_type => 'prepare',
            next_status  => $ALLOCATION_STATUS__PREPARING,
            expected     => {
                allocation_id => $allocation->id,
                destination   =>
                    $allocation->get_prl_delivery_destination->message_name,
            },
        });

        # Reread from database
        $allocation->discard_changes;
        is($allocation->prl_delivery_destination_id,
            $allocation->get_prl_delivery_destination->id,
            'prl_delivery_destination_id is set correctly');
    }
}

sub send_deliver_message : Tests {
    my $self = shift;

    my $allocation = $self->get_allocation;

    $self->test_sending_message({
        allocation   => $allocation,
        message_type => 'deliver',
        next_status  => $ALLOCATION_STATUS__DELIVERING,
        expected     => {
            allocation_id => $allocation->id,
        },
    });
}

sub test_sending_message {
    my ($self, $allocation, $message_type, $next_status, $expected)
        = validated_list(
            \@_,
            allocation   => {
                isa => 'XTracker::Schema::Result::Public::Allocation'
            },
            message_type => { isa => 'Str' },
            next_status  => { isa => 'Int' },
            expected     => { isa => 'HashRef' },
        );

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

    my $message_method = "send_${message_type}_message";
    $allocation->$message_method($self->{msg_factory});

    $xt_to_prl->expect_messages({
        messages => [ {
            type    => $message_type,
            path    => $allocation->prl->amq_queue,
            details => $expected,
        } ],
    });

    # Re-read from database
    $allocation->discard_changes;
    is($allocation->status_id, $next_status,
       'Allocation status correctly set');
}

sub get_allocation {
    my ($self, $args) = @_;

    my $products = $args->{products} // [ $self->{goh_product} ];

    my $shipment = $self->get_shipment({
        products => $products,
    });

    return $shipment->allocations->next;
}

sub get_allocations {
    my ($self, $args) = @_;

    my $products = $args->{products} // [
        $self->{goh_product},
        $self->{dms_product},
    ];

    my $shipment = $self->get_shipment({
        products => $products,
    });

    return $shipment->allocations->all;
}

sub get_shipment {
    my ($self, $args) = @_;

    my $products = $args->{products} // [
        $self->{goh_product},
        $self->{dms_product},
    ];

    my $create_method = $args->{create_method} // 'picked_order';

    note "Create shipment";
    my $shipment = $self->{data_helper}
        ->$create_method( products => $products )
        ->{order_object}
        ->get_standard_class_shipment;

    return $shipment;
}


sub has_siblings :Tests {
    my $self = shift;

    my $allocation = $self->get_allocation;
    ok(! $allocation->has_siblings, 'Allocation has no siblings');

    $allocation = $self->get_allocation({
        products => [ $self->{goh_product}, $self->{dms_product} ],
    });
    ok($allocation->has_siblings, 'Allocation has siblings');
}

=head1 SEE ALSO

L<NAP::Test::Class>

L<XTracker::Schema::Result::Public::Allocation>


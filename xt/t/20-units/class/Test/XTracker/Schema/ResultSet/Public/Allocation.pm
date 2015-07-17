package Test::XTracker::Schema::ResultSet::Public::Allocation;
use NAP::policy "tt", qw/test class/;
use FindBin::libs;
BEGIN {
    extends 'NAP::Test::Class';
    with qw/
        Test::Role::WithSchema
        Test::Role::DBSamples
        XTracker::Role::WithAMQMessageFactory
    /;
};
use Test::XTracker::RunCondition prl_phase => 'prl';

=head1 NAME

Test::XTracker::Schema::ResultSet::Public::Allocation - Unit tests for
XTracker::Schema::ResultSet::Public::Allocation

=cut

use Data::Dumper;

use Test::XT::Data;
use Test::XTracker::Data;
use XTracker::Constants     qw( :application );
use XTracker::Constants::FromDB qw(
    :allocation_item_status
    :allocation_status
    :cancel_reason
    :pws_action
    :storage_type
);
use XTracker::Config::Local ("config_var");

use Test::XTracker::Pick::TestScheduler;
use Test::XT::Fixture::Fulfilment::Shipment;
use Test::XT::Fixture::Fulfilment::SingleItemShipments;
use Test::XT::Fixture::PackingException::Shipment;

BEGIN {

has flow => (
    is      => "ro",
    default => sub {
        my $self = shift;
        return Test::XT::Data->new_with_traits(
            traits => [ "Test::XT::Data::Order" ],
            dbh    => $self->schema->storage->dbh,
        );
    }
);

has two_flat_pids => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        my $self = shift;
        return [
            Test::XTracker::Data->create_test_products({
                storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
                how_many        => 2
            }),
        ];
    },
);

}

sub startup : Tests(startup) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{order_helper} = Test::XT::Data->new_with_traits(
        traits => [ 'Test::XT::Data::Order' ]
    );
    my %product_storage_type = (
        full_product => $PRODUCT_STORAGE_TYPE__FLAT,
        dms_product  => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
    );
    @{$self}{(keys %product_storage_type)} = map {
        Test::XTracker::Data->create_test_products({ storage_type_id => $_ })
    } values %product_storage_type;
}

sub allocation_rs {
    my $self = shift;
    $self->schema->resultset('Public::Allocation')
}

sub allocations_picking_summary {
    my $self = shift;
    return $self->allocation_rs->allocations_picking_summary;
}

sub test__require :Test {
    require_ok('XTracker::Schema::ResultSet::Public::Allocation');
}

sub test_with_active_items : Tests() {
    my $self = shift;

    my @statuses = map {
        $self->rs('AllocationItemStatus')->search({ is_end_state => $_ })->slice(0,0)->single
    } 0,1;

    my $allocation = $self->create_shipment([($self->{full_product}) x 2])->allocations->single;
    for my $status_a ( @statuses ) {
        my @items = $allocation->search_related('allocation_items', undef, {order_by => 'id'});
        $items[0]->update({ status_id => $status_a->id });
        for my $status_b ( @statuses ) {
            $items[1]->update({ status_id => $status_b->id });
            my @found = $self->rs('Allocation')->with_active_items->search({'me.id' => $allocation->id});
            if ( grep { !$_->is_end_state } $status_a, $status_b ) {
                is( @found, 1, sprintf
                    q{calling with_active_items on an allocation with items that aren't in an end state should include allocation (%i) just once},
                    $allocation->id
                ) or diag sprintf q{item statuses were '%s' and '%s'}, $status_a->status, $status_b->status;
            }
            else {
                ok( !@found, sprintf
                    q{calling with_active_items on an allocation without items that aren't in an end state should not include allocation (%i)},
                    $allocation->id
                ) or diag sprintf q{item statuses were '%s' and '%s'}, $status_a->status, $status_b->status;
            }
        }
    }
}

sub test_allocated : Tests() {
    my $self = shift;

    my $allocation = $self->create_shipment([$self->{full_product}])->allocations->single;
    for my $status ( $self->rs('AllocationStatus')->search(undef, {order_by => 'id'})->all ) {
        $allocation->update({status_id => $status->id});
        my $found = !!$self->rs('Allocation')->allocated->find($allocation->id);
        if ( $status->id eq $ALLOCATION_STATUS__ALLOCATED ) {
            ok( $found, sprintf q{calling allocated should include allocation (%i) with a status of '%s'},
                $allocation->id, $status->status );
        }
        else {
            ok( !$found, sprintf q{calling allocated should not include allocation (%i) with a status of '%s'},
                $allocation->id, $status->status );
        }
    }
}

sub test_dms : Tests() {
    my $self = shift;
    my ($full_allocation, $dms_allocation) = map {
        $self->create_shipment([$_])->allocations->single
    } @{$self}{qw/full_product dms_product/};
    ok( $self->rs('Allocation')->dms->find($dms_allocation->id),
        sprintf q{calling dms should include allocation (%i) with prl '%s'},
            map { $_->id, $_->prl->name } $dms_allocation );
    ok( !$self->rs('Allocation')->dms->find($full_allocation->id),
        sprintf q{calling dms should not include allocation (%i) with prl '%s'},
            map { $_->id, $_->prl->name } $full_allocation );
}

sub test_allocated_dms_only : Tests() {
    my $self = shift;

    # The approach taken to test this method is to start from an allocation
    # that is part of the resultset, and change one thing at a time to make
    # sure they don't get selected any more.
    # Successful call
    subtest 'happy path' => sub {
        my $allocation = $self->create_shipment([($self->{dms_product}) x 2])->allocations->single;
        my @found = $self->rs('Allocation')->allocated_dms_only->search({'me.id' => $allocation->id});
        is( @found, 1, sprintf
            q{calling allocated_dms_only should include allocation (%i)},
            $allocation->id );
    };

    subtest q{'dms' call} => sub {
        my $allocation = $self->create_shipment([$self->{full_product}])->allocations->single;
        my @found = $self->rs('Allocation')->allocated_dms_only->search({'me.id' => $allocation->id});
        ok( !@found, 'calling allocated_dms_only should not return allocations with Full PRL' )
            or diag sprintf '... but it returned allocation %i', $allocation->id;
    };

    subtest q{'allocated' call} => sub {
        # Test 'allocated' call
        for my $status ( $self->rs('AllocationStatus')->search(undef, {order_by => 'id'}) ) {
            my $allocation = $self->create_shipment([($self->{dms_product}) x 2])->allocations->single;
            $allocation->update({status_id => $status->id});
            my @found = $self->rs('Allocation')->allocated_dms_only->search({'me.id' => $allocation->id});
            if ( $status->id == $ALLOCATION_STATUS__ALLOCATED ) {
                is( @found, 1, sprintf
                    q{calling allocated_dms_only should return '%s' allocation (%i)},
                    $status->status, $allocation->id );
            }
            else {
                ok( !@found, sprintf
                    q{calling allocated_dms_only should not return '%s' allocation (%i)},
                    $status->status, $allocation->id );
            }
        }
    };

    subtest q{'with_active_items' call} => sub {
        for my $item_status ( $self->rs('AllocationItemStatus')->search(
            # We don't need to test all statuses as we have a unit test for
            # that... just test 'expected' statuses for coverage
            { id => [
                $ALLOCATION_ITEM_STATUS__ALLOCATED,
                $ALLOCATION_ITEM_STATUS__SHORT,
                $ALLOCATION_ITEM_STATUS__CANCELLED,
            ]},
            { order_by => 'id' }
        ) ) {
            my $allocation = $self->create_shipment([($self->{dms_product}) x 2])->allocations->single;
            $allocation->allocation_items->update({status_id => $item_status->id});
            my @found = $self->rs('Allocation')->allocated_dms_only->search({'me.id' => $allocation->id});
            if ( $item_status->is_end_state) {
                ok( !@found, sprintf
                    q{calling allocated_dms_only should not return allocation (%i) with '%s' items},
                    $allocation->id, $item_status->status );
            }
            else {
                is( @found, 1, sprintf
                    q{calling allocated_dms_only should return allocation (%i) with '%s' items},
                    $allocation->id, $item_status->status );
            }
        }
    };

    subtest q{'pick_triggered_by_sibling_allocations' call} => sub {
        my $shipment = $self->create_shipment([@{$self}{qw/full_product dms_product/}]);
        my ($dms_allocation, $full_allocation) = map {
            $shipment->find_related('allocations', { prl_id => $_ })
        } qw/2 1/; # Dematic, Full - TODO DCA-802: harcoded for now, this test will need complete rewriting anyway

        for my $allocation_status (
            $self->rs('AllocationStatus')->search(undef, {order_by => 'id'})
        ) {
            $full_allocation->update({status_id => $allocation_status->id});

            for my $allocation_item_status (
                $self->rs('AllocationItemStatus')->search(undef, {order_by => 'id'})->all
            ) {
                $full_allocation->allocation_items->update({
                    status_id => $allocation_item_status->id
                });
                my @found = $self->rs('Allocation')
                                 ->allocated_dms_only
                                 ->search({'me.id' => $dms_allocation->id});
                if ( $self->do_statuses_trigger_sibling_pick(
                    $allocation_status->id, $allocation_item_status->id
                ) ) {
                    ok( !@found, sprintf
                        q{allocation %i should not be returned as its pick is triggered by sibling (%i) status '%s' and item status '%s'},
                        $dms_allocation->id,
                        $full_allocation->id,
                        $allocation_status->status,
                        $allocation_item_status->status );
                }
                else {
                    is( @found, 1, sprintf
                        q{allocation %i should be returned as its pick is not triggered by sibling (%i) status '%s' and item status '%s'},
                        $dms_allocation->id,
                        $full_allocation->id,
                        $allocation_status->status,
                        $allocation_item_status->status );
                }
            }
        }
    };
}

sub test_pick_triggered_by_sibling_allocations : Tests() {
    my $self = shift;

    {
        my $shipment = $self->create_shipment([($self->{dms_product}) x 2]);
        my $allocation = $shipment->allocations->slice(0,0)->single;
        ok( !($allocation->id ~~ [
                $self->rs('Allocation')->pick_triggered_by_sibling_allocations
            ]),
            sprintf 'allocation %i is not triggered by no post-picking-staging-area sibling allocation',
            $allocation->id );
    }

    my $shipment = $self->create_shipment([@{$self}{qw/full_product dms_product/}]);
    for my $allocation_status (
        $self->rs('AllocationStatus')->search(undef, {order_by => 'id'})->all
    ) {
        my ( $dms_allocation, $full_allocation ) = map {
            $shipment->find_related('allocations', { prl_id => $_ })
        } qw/2 1/; # Dematic, Full - TODO DCA-802: harcoded for now, this test will need complete rewriting anyway
        $full_allocation->update({ status_id => $allocation_status->id });

        for my $allocation_item_status (
            $self->rs('AllocationItemStatus')->search(undef, {order_by => 'id'})->all
        ) {
            $full_allocation->allocation_items->update({
                status_id => $allocation_item_status->id
            });

            my @ids = $self->rs('Allocation')->pick_triggered_by_sibling_allocations;
            # If we expect our statuses to trigger a pick test our id is
            # included...
            if ( $self->do_statuses_trigger_sibling_pick(
                $allocation_status->id, $allocation_item_status->id
            ) ) {
                ok( $dms_allocation->id ~~ \@ids, sprintf
                    q{pick of allocation %i should be triggered by sibling allocation '%s' with item '%s'},
                    $dms_allocation->id,
                    $allocation_status->status,
                    $allocation_item_status->status );
            }
            # ... else check it's not
            else {
                ok( !($dms_allocation->id ~~ \@ids), sprintf
                    q{pick of allocation %i should not be triggered by sibling allocation '%s' with item '%s'},
                    $dms_allocation->id,
                    $allocation_status->status,
                    $allocation_item_status->status );
            }
        }
    }
}

# This sub will return a true value if the given $allocation_status_id and
# $allocation_item_status_id would trigger a pick (note that it doesn't
# consider any other cases, e.g. the statuses don't belong to a PRL with a
# post picking staging area)
sub do_statuses_trigger_sibling_pick {
    my ( $self, $allocation_status_id, $allocation_item_status_id ) = @_;

    # If the allocation has got as far as PICKED, it won't trigger anything
    my $valid_allocation_statuses = [
        $ALLOCATION_STATUS__REQUESTED,
        $ALLOCATION_STATUS__ALLOCATED,
        $ALLOCATION_STATUS__PICKING,
        $ALLOCATION_STATUS__STAGED,
    ];

    # It needs some still-active items (and here, a PICKED item still counts
    # as active if it's parent allocation isn't PICKED yet, because we're just
    # trying to exclude allocations that consist only of SHORT or CANCELLED
    # items)
    my $valid_allocation_item_statuses = [
        $ALLOCATION_ITEM_STATUS__REQUESTED,
        $ALLOCATION_ITEM_STATUS__ALLOCATED,
        $ALLOCATION_ITEM_STATUS__PICKING,
        $ALLOCATION_ITEM_STATUS__PICKED,
    ];

    return !! (
        $allocation_status_id ~~ $valid_allocation_statuses
        &&
        $allocation_item_status_id ~~ $valid_allocation_item_statuses
    );
}

sub test_with_siblings_in_prl_with_staging_area : Tests() {
    my $self = shift;

    my $prl_with_staging_area = 'Full';
    for (
        [ 'mixed allocation shipment' => @{$self}{qw/full_product dms_product/} ],
        [ 'single dms allocation shipment' => $self->{dms_product} ],
        [ 'single full allocation shipment' => $self->{full_product} ],
    ) {
        my ( $shipment_type, @products ) = @$_;
        subtest "$shipment_type allocation tests ok" => sub {
            my @allocations = $self->create_shipment(\@products)->allocations;
            # We loop through all allocations in our tests to prevent us from
            # identifying the source allocation from matching against itself
            # when looking amongst its siblings. Shipments with mixed
            # allocations and single dms allocation would otherwise return
            # false positives.
            for my $allocation ( @allocations ) {
                my @found = $self->rs('Allocation')
                                 ->with_siblings_in_prl_with_staging_area()
                                 ->search({'me.id' => $allocation->id});
                my ($sibling_allocation) = grep { $_->id != $allocation->id } @allocations;
                if ( !$sibling_allocation ) {
                    ok( !@found, sprintf
                        q{calling with_siblings_in_prl_with_staging_area should not return siblingless %s allocation (%i)},
                        $allocation->prl->name, $allocation->id );
                }
                elsif ( $sibling_allocation->prl->name eq $prl_with_staging_area ) {
                    is( @found, 1, sprintf
                        q{calling with_siblings_in_prl_with_staging_area should return %s allocation (%i) with expected sibling %s allocation},
                        $allocation->prl->name, $allocation->id, $prl_with_staging_area );
                }
                else {
                    ok( !@found, sprintf
                        q{calling with_siblings_in_prl_with_staging_area should not return %s allocation (%i) without expected sibling %s allocations},
                        $allocation->prl->name, $allocation->id, $prl_with_staging_area );
                }
            }
        }
    }
}

sub test_with_siblings_in_status : Tests() {
    my $self = shift;

    my $shipment = $self->create_shipment([@{$self}{qw/full_product dms_product/}]);
    my ( $expected_allocation, $updated_allocation ) = map {
        $shipment->find_related('allocations', { prl_id => $_ })
    } qw/2 1/; # Dematic, Full - TODO DCA-802: harcoded for now, this test will need complete rewriting anyway

    # Look for any status
    my $search_for_status
        = $self->rs('AllocationStatus')->find($ALLOCATION_STATUS__PICKED);
    # Set our allocation to the above status so we don't return false positives
    # against the source allocation
    $expected_allocation->update({status_id => $search_for_status->id});

    for my $status ( $self->rs('AllocationStatus')->search({},{order_by => 'id'})->all ) {
        # Update the allocation we're expecting to match the status on
        $updated_allocation->update({status_id => $status->id});
        my @found = $self->rs('Allocation')
                         ->with_siblings_in_status($search_for_status->id)
                         ->search({'me.id' => $expected_allocation->id});
        if ( $search_for_status->id == $status->id ) {
            is( @found, 1, sprintf
                q{calling with_siblings_in_status should include allocation (%i) with sibling allocation status '%s'},
                $expected_allocation->id, $updated_allocation->status->status );
        }
        else {
            ok( !@found, sprintf
                q{calling with_siblings_in_status should not include allocation (%i) with sibling allocation status '%s'},
                $expected_allocation->id, $updated_allocation->status->status );
        }
    }
}

sub test_with_siblings_with_items_in_status : Tests() {
    my $self = shift;

    my $shipment = $self->create_shipment([@{$self}{qw/full_product dms_product/}]);
    my ( $expected_allocation, $updated_allocation ) = map {
        $shipment->find_related('allocations', { prl_id => $_ })
    } qw/2 1/; # Dematic, Full - TODO DCA-802: harcoded for now, this test will need complete rewriting anyway

    # Any status
    my $search_for_status
        = $self->rs('AllocationItemStatus')->find($ALLOCATION_ITEM_STATUS__PICKED);
    # Set our allocation's items to the above status so we don't return false
    # positives against the source allocation
    $expected_allocation->allocation_items->update({status_id => $search_for_status->id});

    for my $status ( $self->rs('AllocationItemStatus')->search({},{order_by => 'id'})->all ) {
        # Update the allocation we're expecting to match the status on
        $updated_allocation->allocation_items->update({status_id => $status->id});
        my @found = $self->rs('Allocation')
                         ->with_siblings_with_items_in_status($search_for_status->id)
                         ->search({'me.id' => $expected_allocation->id});
        my $updated_allocation_item
            = $updated_allocation->allocation_items
                                 ->related_resultset('status')
                                 ->slice(0,0)
                                 ->single;
        if ( $search_for_status->id == $status->id ) {
            is( @found, 1, sprintf
                q{calling with_siblings_with_items_in_status should include allocation (%i) with sibling allocation item status '%s'},
                $expected_allocation->id, $updated_allocation_item->status );
        }
        else {
            ok( !@found, sprintf
                q{calling with_siblings_with_items_in_status should not include allocation (%i) with sibling allocation item status '%s'},
                $expected_allocation->id, $updated_allocation_item->status );
        }
    }
}

sub create_shipment {
    my ( $self, $product ) = @_;
    return $self->{order_helper}->new_order(products => $product)
        ->{order_object}
        ->get_standard_class_shipment;
}

sub create_selected_shipment {
    my ($self, $product) = @_;
    my $shipment_row = $self->create_shipment($product);

    Test::XTracker::Data::Order->allocate_shipment( $shipment_row );
    Test::XTracker::Data::Order->select_shipment( $shipment_row );

    return $shipment_row;
}

# Test allocations_picking_summary()
sub test__allocations_picking_summary :Tests() {
    my ($self) = @_;

    my $shipment = $self->create_selected_shipment( $self->two_flat_pids );

    # Set some additional fields in the shipment and allocations
    $shipment->update( { sla_cutoff => \'now()' } );
    my $allocation = $shipment->allocations->first;
    $allocation->update({ pick_sent => \'now()' });
    $allocation->allocation_items->first->update({ picked_at => \'now()' });

    my $results = $self->allocations_picking_summary;

    # Find the entry in summary hash for shipment we created above
    my $ent = $results->{shipments}->{$shipment->id};

    # Check the grand total of items
    ok( defined($results->{number_items}), "grand total of items is present" );
    my $item_count_start = $results->{number_items};

    # Check the data items for the shipment
    is( $ent->{id}, $shipment->id, "shipment ID is correct" );
    my $channel = $shipment->order->channel;
    is( $ent->{channel}, $channel->config_name, "channel name is correct" );
    is( $ent->{number_items}, 2, "number of items is correct" );
    ok( defined( $ent->{sla_timer} ), "SLA timer is present" );
    isa_ok( $ent->{pick_sent}, 'DateTime', "pick sent time" );
    ok( !$ent->{is_premier}, "premier indicator is false" );
    is( @{$ent->{prls}}, 1, "PRL list has one entry" );
    is( $ent->{prls}->[0], 'Full', "PRL list contains Full PRL" );


    # Check the allocation list
    my $a_ent = $ent->{allocs}->[0];
    is( @{$ent->{allocs}},       1,               "allocation list has one entry" );
    is( $a_ent->{number_items},  2,               "allocation entry has two items" );
    is( $a_ent->{number_picked}, 1,               "allocation entry has one picked items" );
    is( $a_ent->{id},            $allocation->id, "allocation entry has correct ID" );
    is( $a_ent->{prl},           'Full',          "allocation entry has Full PRL" );
    isa_ok( $a_ent->{pick_sent}, 'DateTime', "allocation entry pick sent time" );
    isa_ok( $a_ent->{last_pick}, 'DateTime', "allocation entry last pick time" );
    ok( !$a_ent->{scanned_onto_conveyor}, "allocation entry has been scanned onto conveyor" );
}

sub test_shipment_present_in_allocations_picking_summary {
    my ($self, $shipment_row) = @_;
    my $picking_summary = $self->allocations_picking_summary;

    my $shipment_record = $picking_summary->{shipments}->{ $shipment_row->id };
    ok( $shipment_record, "Found the Shipment record" );

    return $picking_summary->{number_items};
}

sub test_shipment_absent_in_allocations_picking_summary {
    my ($self, $shipment_row) = @_;
    my $picking_summary = $self->allocations_picking_summary;

    my $shipment_record = $picking_summary->{shipments}->{ $shipment_row->id };
    ok( ! $shipment_record, "Didn't find the Shipment record" )
        or diag("The found record is: " . Data::Dumper->new([$shipment_record])->Maxdepth(3)->Dump());

    return $picking_summary->{number_items};
}

sub test__allocations_picking_summary__cancelled_shipment_during_picking : Tests() {
    my $self = shift;
    note "Display if the entire shipment is cancelled _after_ Pick is sent";

    my $two_flat_pids = $self->two_flat_pids;
    my $fixture = Test::XT::Fixture::Fulfilment::Shipment
        ->new({
            pids => $two_flat_pids,
        })
        ->with_selected_shipment();
    my $shipment_row = $fixture->shipment_row;

    note "Pre-test sanity check";
    my $number_items_before
        = $self->test_shipment_present_in_allocations_picking_summary(
            $shipment_row,
        );

    note "Cancel shipment after Pick sent";
    $fixture->with_cancelled_shipment();

    my $number_items_after
        = $self->test_shipment_present_in_allocations_picking_summary(
            $shipment_row,
        );

    is(
        $number_items_after - $number_items_before,
        0,
        "ShipmentItems for products in order still there",
    );
}

sub run_pick_scheduler {
    my ($self, $shipment_row) = @_;

    return unless (config_var("PickScheduler", "version") // 0) == 2;

    my $pick_scheduler = Test::XTracker::Pick::TestScheduler->new(
        # msg_factory => $xt_to_prls,
        test_shipment_ids => [ $shipment_row->id ],
        packing_remaining_capacity    => 100, # Plenty of space
        mock_sysconfig_parameter => {
            dcd_picking_total_capacity => 100, # Plenty of pick capacity
            full_induction_capacity    => 100, # plenty of pick capacity
        }
    );
    $pick_scheduler->schedule_allocations();
}

sub test__allocations_picking_summary__full_and_dematic : Tests() {
    my $self = shift;

    # * Fixture
    # Shipment with two Shipment Items
    # 1 Full Allocation
    # 1 Dematic Allocation
    #
    # * Scenario
    # Send Pick for Full - appears
    # Container Ready for Full - appears
    # Pick Complete for Full - appears
    #   Full allocation is STAGED and Dematic is now waiting for it to
    #   be inducted
    # Induct Full Container - triggers pick for Dematic - appears
    # Pick Dematic - disappears

    note "Full + Dematic allocations";

    my $fixture = Test::XT::Fixture::Fulfilment::Shipment
        ->new({
            pids => [
                $self->{full_product},
                $self->{dms_product},
            ],
        });
    $fixture->with_allocated_shipment();

    my $shipment_row = $fixture->shipment_row;
    my $full_allocation_row = $shipment_row->allocations->search({
        'prl.name' => "Full",
    },{
        join => 'prl',
    })->first;
    my $full_shipment_item_row
        = $full_allocation_row->allocation_items->first->shipment_item;


    note "Pre-test sanity check";
    my $number_items_before
        = $self->test_shipment_absent_in_allocations_picking_summary(
            $shipment_row,
        );

    my $full_container_row = $fixture->additional_container_rows->[0];
    note "Picking Full into container (" . $full_container_row->id . ")";

    note "Send Pick for Full";
    $full_allocation_row->pick( $self->msg_factory, $APPLICATION_OPERATOR_ID );
    $self->test_shipment_present_in_allocations_picking_summary(
        $shipment_row,
    );

    $fixture->pick_allocation_into_container_and_test(
        "Full",
        $full_allocation_row,
        $full_container_row,
        sub {
            $self->test_shipment_present_in_allocations_picking_summary(
                $shipment_row,
            );
        },
    );
    $self->test_shipment_present_in_allocations_picking_summary(
        $shipment_row,
    );


    note "Induct Full Container - triggers pick for Dematic - appears";
    $fixture->with_container_inducted( $full_container_row );
    $self->run_pick_scheduler($shipment_row);
    $fixture->discard_changes();

    my $dematic_allocation_row = $fixture->dematic_allocation_row;
    $dematic_allocation_row->discard_changes;
    my $dematic_allocation_id = $dematic_allocation_row->id;
    isnt(
        $dematic_allocation_row->pick_sent,
        undef,
        "Dematic Allocation ($dematic_allocation_id) has pick_sent date",
    );

    $self->test_shipment_present_in_allocations_picking_summary(
        $shipment_row,
    );



    note "* Now pick the Dematic Allocation";
    my $dematic_container_row = $fixture->additional_container_rows->[1];
    $fixture->pick_allocation_into_container_and_test(
        "Dematic",
        $dematic_allocation_row,
        $dematic_container_row,
        sub {
            $self->test_shipment_present_in_allocations_picking_summary(
                $shipment_row,
            );
        },
    );
    $self->test_shipment_absent_in_allocations_picking_summary(
        $shipment_row,
    );
}

sub test__allocations_picking_summary__cancelled_shipment_item_before_pick_message : Tests() {
    my $self = shift;

    # Cancelled item in the same Allocation
    note "Don't display if one item is cancelled and the remaining one picked";

    my $fixture = Test::XT::Fixture::Fulfilment::Shipment
        ->new({
            pids => $self->two_flat_pids,
        });
    my $shipment_row = $fixture->shipment_row;

    note "Cancelling first ShipmentItem before Pick is sent to PRL";
    my ( $cancelled_shipment_item_row, undef ) = $shipment_row->shipment_items;
    $fixture->with_cancelled_shipment_item( $cancelled_shipment_item_row );

    note "Select and send Pick to PRL";
    $fixture->with_selected_shipment();

    note "Pre-test sanity check";
    my $number_items_before
        = $self->test_shipment_present_in_allocations_picking_summary(
            $shipment_row,
        );


    note "Run: Pick remaining ShipmentItem";
    $fixture->with_picked_shipment($shipment_row);

    note "Test again, Shipment should now be gone";
    my $number_items_after
        = $self->test_shipment_absent_in_allocations_picking_summary(
            $shipment_row,
        );

    is(
        $number_items_after - $number_items_before,
        -1,
        "ShipmentItem for picked product in order removed from number_item reported",
    );

}

sub test__allocations_picking_summary__cancelled_shipment_item__qc_replacement_pick : Tests() {
    my $self = shift;

    # Size change leading to cancelled ShipmentItem + new ShipmentItem
    # in different Allocation

    # If part of a shipment has been cancelled (due to size change,
    # faulty item etc), when the remaining part of the shipment (this
    # can be in the same PRL or in a different PRL) has been fully
    # picked, the entry is not present on from the page.
    # I.e. it has gone past Packing once, PE, and is present while
    # awaiting replacement pick, but not once the replacement is
    # picked
    note "Don't display if one item is cancelled and the remaining one picked";

    my $fixture = Test::XT::Fixture::PackingException::Shipment
        ->new({
            flow => $self->flow,
            pids => $self->two_flat_pids,
        })
        ->with_selected_shipment()
        ->with_picked_shipment()
        ->with_picked_container_in_commissioner();
    my $shipment_row = $fixture->shipment_row;
    my ( $cancelled_shipment_item_row, undef ) = $shipment_row->shipment_items;
    $fixture
        ->with_cancelled_shipment_item( $cancelled_shipment_item_row )
        ->with_additional_shipment_item( $fixture->pids->[0] )
        ->with_selected_shipment();

    note "Pre-test sanity check";
    my $number_items_before
        = $self->test_shipment_present_in_allocations_picking_summary(
            $shipment_row,
        );

    note "Run: Pick remaining ShipmentItem";
    $fixture->with_picked_shipment($shipment_row);

    note "Test again, Shipment should now be gone";
    my $number_items_after
        = $self->test_shipment_absent_in_allocations_picking_summary(
            $shipment_row,
        );

    is(
        $number_items_after - $number_items_before,
        0 - $fixture->shipment_row->shipment_items->count,
        "ShipmentItems for all ShipmentItems removed from number_item reported",
    );
}

sub test__allocations_picking_summary__cancelled_shipment_item__qc_replacement_pick_which_is_then_cancelled : Tests() {
    my $self = shift;

    # Size change leading to cancelled ShipmentItem + new ShipmentItem
    # in different Allocation, and this allocation is cancelled before
    # Picking starts
    note "Don't display Shipment if replacement item is cancelled";

    my $fixture = Test::XT::Fixture::PackingException::Shipment
        ->new({
            flow => $self->flow,
            pids => $self->two_flat_pids,
        })
        ->with_selected_shipment()
        ->with_picked_shipment()
        ->with_picked_container_in_commissioner();
    my $shipment_row = $fixture->shipment_row;

    note "Cancel one item, to get a replacement allocation";
    my ( $cancelled_shipment_item_row, undef ) = $shipment_row->shipment_items;
    $fixture
        ->with_cancelled_shipment_item( $cancelled_shipment_item_row )
        ->with_additional_shipment_item( $fixture->pids->[0] );

    note "Pre-test sanity check";
    my $number_items_before
        = $self->test_shipment_present_in_allocations_picking_summary(
            $shipment_row,
        );

    note "Cancel replacement ShipmentItem before Pick is sent to PRL";
    my ( $cancelled_replacement_shipment_item_row )
        = reverse $shipment_row->shipment_items->search(
            {},
            { order_by => "id" },
        )->all;
    $fixture->with_cancelled_shipment_item(
        $cancelled_replacement_shipment_item_row,
    );

    note "Test after cancelling replacement item, Shipment should now be gone";
    my $number_items_after
        = $self->test_shipment_absent_in_allocations_picking_summary(
            $shipment_row,
        );
}

sub test__filter_is_allocation_pack_space_allocated : Tests() {
    my $self = shift;

    note "DCD counts pack space in allocations";

    note "*** Setup";
    my @fixtures = map {
        Test::XT::Fixture::Fulfilment::Shipment
            ->new({ pids => [ $self->{dms_product} ] })
            ->with_allocated_shipment() }
        1..2;

    my @allocation_rows =
        map { $_->shipment_row->allocations->all }
        @fixtures;
    my $allocation_ids = [ map { $_->id } @allocation_rows ];
    my $allocation_me = $self->allocation_rs->current_source_alias;
    my $rs = $self->allocation_rs->search({
        "$allocation_me.id" => $allocation_ids,
    });

    my $allocation_count;

    note "*** DCD allocated - 0";
    $allocation_count = $rs->filter_is_allocation_pack_space_allocated()->count;
    is($allocation_count, 0, "DCD in allocated: no pack space");


    note "*** DCD picking - 2";
    note "** Setup";
    $_->with_selected_shipment() for @fixtures;

    note "** Run";
    $allocation_count = $rs->filter_is_allocation_pack_space_allocated()->count;

    note "** Test";
    is($allocation_count, 2, "DCD picked: using pack space");


    note "*** DCD picked - 0";
    note "** Setup";
    $_->with_picked_shipment() for @fixtures;

    note "** Run";
    $allocation_count = $rs->filter_is_allocation_pack_space_allocated()->count;

    note "** Test";
    is($allocation_count, 0, "DCD picked: using pack space");


    note "*** DCD picked, packed - 0";
    note "** Setup";
    $_->with_packed_shipment->with_dispatched_shipment() for @fixtures;

    note "** Run";
    $allocation_count = $rs->filter_is_allocation_pack_space_allocated()->count;

    note "** Test";
    is($allocation_count, 0, "DCD packed: using pack space");

}

sub test__filter_staged : Tests {
    my $self = shift;

    note "*** Setup";
    note "At least one allocation in picked";
    my $fixture_staged = Test::XT::Fixture::Fulfilment::Shipment
        ->new({ pids => [ $self->{full_product} ] })
        ->with_staged_shipment();
    my $fixture_packed = Test::XT::Fixture::Fulfilment::Shipment
        ->new({ pids => [ $self->{full_product} ] })
        ->with_staged_shipment()
        ->with_dispatched_shipment();

    my $staged_allocation_id = $fixture_staged->shipment_row->allocations->first->id;
    my $packed_allocation_id = $fixture_packed->shipment_row->allocations->first->id;
    my @staged_shipment_ids = $self->allocation_rs->search({
        "me.id" => { -in => [ $staged_allocation_id, $packed_allocation_id ] },
    })->filter_staged()->get_column("id")->all;

    is_deeply(
        \@staged_shipment_ids,
        [ $staged_allocation_id ],
        "Only Staged allocations found",
    );
}

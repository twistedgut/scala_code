package Test::XT::DC::Messaging::Plugins::PRL::ContainerReady;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};
use Test::XTracker::RunCondition
    prl_phase => 'prl',
    export => [qw( $prl_rollout_phase )];

=head1 NAME

Test::XT::DC::Messaging::Plugins::PRL::ContainerReady - Unit tests for XT::DC::Messaging::Plugins::PRL::ContainerReady

=head1 DESCRIPTION

Unit tests for XT::DC::Messaging::Plugins::PRL::ContainerReady

=cut

use XT::DC::Messaging::Plugins::PRL::ContainerReady;
use Test::XT::Data;
use Test::XTracker::Data;
use Test::XT::Data::Container;
use XTracker::Constants::FromDB qw/
    :allocation_item_status
    :allocation_status
    :container_status
    :pack_lane_attribute
    :shipment_item_status
    :storage_type
/;
use XTracker::AllocateManager;
use Test::XTracker::LocationMigration;
use XTracker::Config::Local qw/config_var/;
use Test::XTracker::Data::PackRouteTests;
use Test::XT::Fixture::Fulfilment::Shipment;

sub startup : Tests(startup) {
    my $self = shift;

    $self->SUPER::startup;

    # Test::XT::Data instance
    $self->{'test_xt_data'} = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );

    my $plt = Test::XTracker::Data::PackRouteTests->new;

    my $packlane_config = [{
        pack_lane_id => 1,
        human_name => 'pack_lane_1',
        internal_name => 'DA.PO01.0000.CCTA01NP02',
        capacity => 14,
        active => 1,
        attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__SINGLE ]
    }];

    $plt->reset_and_apply_config($packlane_config);

}

# Check we do the right thing for more than one allocation in a container
sub lots_of_one_line_shipments : Tests() {
    my $self = shift;

    note "* Setup";

    # Five products
    my @products = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many => 5,
    });

    # Five shipments
    my @shipments = map {
        $self->{'test_xt_data'}->new_order( products => [$_] )->{'shipment_object'};
    } @products;

    # Some counters
    my @shipment_items = map { $_->shipment_items } @shipments;
    my $stock_check = $self->setup_counters(
        "Pre-Allocation",
        # variant ids for all shipment items in all shipments
        map { $_->variant->id } @shipment_items
    );

    # Start picking each of the shipments
    my @allocations = map { $_->allocations } @shipments;
    # Mark every allocation item as PICKING
    $_->update({ status_id => $ALLOCATION_ITEM_STATUS__PICKING })
        for map { $_->allocation_items } @allocations;
    # Mark every allocation as picking
    $_->update({ status_id => $ALLOCATION_STATUS__PICKING }) for @allocations;

    # Everything's gonna go in the same container
    my $container_id = Test::XT::Data::Container->get_unique_id();

    # ItemPicked messages
    $self->send_message( $self->create_message(
        ItemPicked => {
            allocation_id => $_->allocation->id,
            client        => $_->shipment_item->variant->prl_client,
            pgid          => 'p12345',
            user          => "Dirk Gently",
            sku           => $_->shipment_item->variant->sku,
            container_id  => $container_id,
        }
    ) ) for map { $_->allocation_items } @allocations;

    $stock_check->( 'Post-ItemPicked', {} ); # No changes

    # Shipment items shouldn't be picked
    $self->check_shipment_items({
        container_id   => undef,
        status_id      => $SHIPMENT_ITEM_STATUS__NEW,
        shipment_items => \@shipment_items,
    });

    # Monitor sent messages
    my $message_queue = Test::XTracker::MessageQueue->new;
    my $message_destination = config_var("PRL", "conveyor_queue")
        or fail("Could not find queue in config");
    $message_queue->clear_destination($message_destination);

    note "* Run";
    # One big-ass ContainerReady with everything in it
    # Send a container ready
    $self->send_message( $self->create_message(
        ContainerReady => {
            container_id => $container_id,
            allocations  => [ map {{ allocation_id => $_->id }} @allocations ],
            prl          => "dcd", # Dematic, will send RouteRequest
        }
    ) );


    note "* Test";
    $message_queue->assert_messages({
        destination  => $message_destination,
        assert_body => superhashof({
            container_id => $container_id->as_id,
            destination  => "DA.PO01.0000.CCTA01NP02", # pack_lane_2
        }),
    }, "Check that data structure in sent message is the same as expected." );

    $stock_check->( 'Post-ContainerReady', { 'Main Stock' => -1 } );

    # Shipment items are now picked
    $self->check_shipment_items({
        container_id   => $container_id,
        status_id      => $SHIPMENT_ITEM_STATUS__PICKED,
        shipment_items => \@shipment_items,
    });
}

# Check the handler is wired up correctly using a happy path
sub handler_happy_path : Tests() {
    my $self = shift;

    my $container_id = Test::XT::Data::Container->get_unique_id();

    my ($shipment, $stock_check) = $self->_get_shipment_with_two_picked_items({
        container_id => $container_id,
    });

    my ($allocation) = $shipment->allocations;

    # Send a container ready
    $self->send_message( $self->create_message(
        ContainerReady   => {
            container_id => $container_id,
            allocations  => [ { allocation_id => $allocation->id } ],
            prl          => "Full",
        }
    ) );

    $stock_check->( 'Post-ContainerReady', { 'Main Stock' => -1 } );

    # Shipment items are now picked
    $self->check_shipment_items({
        container_id   => $container_id,
        status_id      => $SHIPMENT_ITEM_STATUS__PICKED,
        shipment_items => [$shipment->shipment_items],
    });
}

sub handler_route_to_integration : Tests() {
    my $self = shift;

    SKIP: {
        skip 'Only in PRL phase 2+', 1 unless $prl_rollout_phase >= 2;

        my ($container_id) = Test::XT::Data::Container->create_new_containers({
            status   => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
        });

        note "Create a mixed DCD and GOH shipment, pretend GOH part has been prepared";
        my $dcd_and_goh_fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
            prl_pid_counts => {
                'Dematic' => 1,
                'GOH'     => 1,
            },
        })->with_prepared_goh_allocation;

        note "DCD allocation is in picking and item has been picked into a container waiting for container ready";
        $dcd_and_goh_fixture->dematic_allocation_row->update({
            status_id    => $ALLOCATION_STATUS__PICKING,
        });
        foreach my $allocation_item ($dcd_and_goh_fixture->dematic_allocation_row->allocation_items) {
            $allocation_item->update({
                status_id    => $ALLOCATION_ITEM_STATUS__PICKED,
                picked_into  => $container_id,
            });
        }

        note "Start monitoring messages sent to conveyor";
        my $message_queue = Test::XTracker::MessageQueue->new;
        my $message_destination = config_var("PRL", "conveyor_queue")
            or fail("Could not find queue in config");
        $message_queue->clear_destination($message_destination);

        note "Send a container_ready for the DCD container";
        $self->send_message( $self->create_message(
            ContainerReady => {
                container_id => $container_id,
                allocations  => [ { allocation_id => $dcd_and_goh_fixture->dematic_allocation_row->id } ],
                prl          => "dcd", # Dematic, will send RouteRequest
            }
        ) );

        note "Check that we sent the container to integration";
        $message_queue->assert_messages({
            destination  => $message_destination,
            assert_body => superhashof({
                '@type'      => 'route_request',
                container_id => $container_id->as_id,
                destination  => "DA.GH01.0000.GOH_01", # goh integration lane
            }),
        }, "route_request to integration has been sent" );

        note "Check that we made an integration_container row in the db";
        my $integration_container_rs = $self->schema->resultset('Public::IntegrationContainer')->search({
            container_id => $container_id->as_id
        });
        is ($integration_container_rs->count, 1, "One integration container has been made");
        my $integration_container = $integration_container_rs->first;
        is ($integration_container->prl_id, $dcd_and_goh_fixture->goh_allocation_row->prl->id,
            "integration container has correct prl_id (goh)");
        is ($integration_container->from_prl_id, $dcd_and_goh_fixture->dematic_allocation_row->prl->id,
            "integration container has correct from_prl_id (dcd)");
        is ($integration_container->arrived_at, undef,
            "integration container is not yet marked as arrived");
        foreach my $allocation_item ($dcd_and_goh_fixture->dematic_allocation_row->allocation_items) {
            my $integration_container_item_rs =
                $integration_container->integration_container_items->search({
                   allocation_item_id => $allocation_item->id,
            });
            is ($integration_container_item_rs->count, 1,
                "integration_container_item created for allocation item ".$allocation_item->id);

            ok(
                !scalar( grep { !$_->is_picked } $integration_container_item_rs->all),
                'Check that all items in Integration container are in Picked status'
            );
        }

        ok(
            !$_->pack_lane_id,
            'Check that shipment item containers are not assigned to any pack lane'
        ) for $integration_container
            ->allocation_items
            ->search_related('shipment_item')
            ->search_related('container')
            ->all;

    } # END of SKIP
}

sub no_route_request_messages_for_hooks :Tests {
    my $self = shift;

    SKIP: {
        skip 'Only in PRL phase 2+', 1 unless $prl_rollout_phase >= 2;

        my ($hook_id) = Test::XT::Data::Container->create_new_containers({
            status             => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
            final_digit_length => 4,
            prefix             => 'KH',
        });

        note 'Create a GOH shipment';
        my $dcd_and_goh_fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
            prl_pid_counts => {
                GOH     => 1,
            },
        });

        note 'Start monitoring messages sent to conveyor';
        my $message_queue = Test::XTracker::MessageQueue->new;
        my $message_destination = config_var(PRL => 'conveyor_queue')
            or fail("Could not find queue in config");
        $message_queue->clear_destination($message_destination);

        note 'Send a container_ready for the hook';
        $self->send_message( $self->create_message(
            ContainerReady => {
                container_id => $hook_id,
                allocations  => [ { allocation_id => $dcd_and_goh_fixture->goh_allocation_row->id } ],
                prl          => 'goh',
            }
        ) );

        note 'Check that we sent the container to integration';
        $message_queue->assert_messages({
            destination  => $message_destination,
            assert_count => 0,
            assert_body  => superhashof({
                '@type' => 'route_request',
            }),
        }, 'No route_request messages were sent' );

        ok
            !$self->schema->resultset('Public::Container')->find( $hook_id )->pack_lane_id,
            'No pack lane assigne to the hook';

    } # END of SKIP
}

sub check_shipment_items {
    my ( $self, $args ) = @_;
    for my $si ( @{ $args->{'shipment_items'} } ) {
        note sprintf("Shipment Item [%d], SKU [%s]", $si->id, $si->variant->sku );
        # Clear out any cached data
        $si->discard_changes;
        # Check the container_id ... isn't
        is( $si->container_id, $args->{'container_id'}, "Shipment Item container is correct" );
        # Check the status is still unpicked
        is( $si->shipment_item_status_id, $args->{'status_id'}, "Shipment Item status ID is correct" );
    }
}

# Given a name for a snapshot, and a list of variant IDs, sets up
# LocationMigration objects for each, and returns a subref that you can pass a
# new snapshot name to, and a diff in the form for `stock_status` (see
# LocationMigration docs).
sub setup_counters {
    my ( $self, $start_state, @variant_ids ) = @_;

    # Setup the initial LocationMigration objects, with a starting snapshot
    my @counters = map {
        my $counter = Test::XTracker::LocationMigration->new( variant_id => $_ );
        $counter->snapshot( $start_state );
        $counter;
    } @variant_ids;

    my $previous_snapshot = $start_state;

    # Return a closure sub that compares what you pass in, and sets a new
    # snapshot
    return sub {
        my ( $new_snapshot_name, $diff ) = @_;
        $_->snapshot( $new_snapshot_name ) for @counters;
        $_->test_delta(
            from         => $previous_snapshot,
            to           => $new_snapshot_name,
            stock_status => $diff,
        ) for @counters;
        $previous_snapshot = $new_snapshot_name;
    };
}

# Get the shipment object that has two items and is in the state just before
# "Container ready" is sent from PRL. Both of its items are "picked" in PRL.
#
# Returns list with shipment object as a first item and code ref used for stock checks
# - as a second one.
#
sub _get_shipment_with_two_picked_items {
    my ($self, $args) = @_;

    my $container_id = $args->{container_id} || Test::XT::Data::Container->get_unique_id();

    # Shipment with two flat items in it
    my $shipment = $self->{'test_xt_data'}->new_order( products => [
            Test::XTracker::Data->create_test_products({
                storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
                how_many => 2
            })],
        )->{'shipment_object'};

    my $stock_check = $self->setup_counters(
        "Pre-Allocation",
        map { $_->variant->id } $shipment->shipment_items
    );

    my ($allocation) = $shipment->allocations;

    # Commence picking... this bit is a hack
    $_->update({ status_id => $ALLOCATION_ITEM_STATUS__PICKING }) for
        $allocation->allocation_items;
    $allocation->update({ status_id => $ALLOCATION_STATUS__PICKING });

    # Pick it
    $self->send_message( $self->create_message(
        ItemPicked => {
            allocation_id => $allocation->id,
            client => $_->shipment_item->variant->prl_client,
            pgid => 'p12345',
            user => "Dirk Gently",
            sku => $_->shipment_item->variant->sku,
            container_id => $container_id,
        }
    ) ) for $allocation->allocation_items;

    $stock_check->( 'Post-ItemPicked', {} ); # No changes

    # Shipment items shouldn't be picked
    my @shipment_items = $shipment->shipment_items;
    $self->check_shipment_items({
        container_id => undef,
        status_id => $SHIPMENT_ITEM_STATUS__NEW,
        shipment_items => \@shipment_items,
    });


    return $shipment, $stock_check;
}

sub cancelled_items_are_moved_to_cancel_pending_after_they_picked_in_prl : Tests() {
    my $self = shift;

    my $container_id = Test::XT::Data::Container->get_unique_id();
    my ($shipment, $stock_check) = $self->_get_shipment_with_two_picked_items({
        container_id => $container_id,
    });


    note 'Move first shipment into "Cancel pending" status';
    # order matters here to distinguish the first item for sure, then the same criteria
    # is used while checking the results
    $shipment->shipment_items->search(undef, {order_by => 'id'})->first->set_cancelled(1);


    my ($allocation) = $shipment->allocations;

    note 'Send a container ready';
    $self->send_message( $self->create_message(
        ContainerReady   => {
            container_id => $container_id,
            allocations  => [ { allocation_id => $allocation->id } ],
            prl          => "Full",
        }
    ) );

    $stock_check->( 'Post-ContainerReady', { 'Main Stock' => -1 } );

    my @shipment_items = $shipment->shipment_items->search(undef, {order_by => 'id'})->all;

    note 'First shipment items is "cancel pending" now';
    $self->check_shipment_items({
        container_id   => $container_id,
        status_id      => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
        shipment_items => [ $shipment_items[0] ],
    });

    note 'Last shipment items is "picked" now';
    $self->check_shipment_items({
        container_id   => $container_id,
        status_id      => $SHIPMENT_ITEM_STATUS__PICKED,
        shipment_items => [ $shipment_items[1] ],
    });
}

sub test_second_container_ready_does_not_affect_inventory : Tests() {
    my $self = shift;

    my $container_id = Test::XT::Data::Container->get_unique_id();
    my ($shipment, $stock_check) = $self->_get_shipment_with_two_picked_items({
        container_id => $container_id,
    });

    my ($allocation) = $shipment->allocations;
    my ($allocation_item) = $allocation->allocation_items;
    my $shipment_item = $allocation_item->shipment_item;

    my $quantity = $self->schema->resultset('Public::Quantity')->find({
        variant_id  => $shipment_item->get_true_variant->id,
        location_id => $allocation->prl_location->id,
        channel_id  => $shipment->get_channel->id,
    });

    # Don't think this will ever happen, but best to be safe.
    die "Can't find a quantity record" if ! $quantity;

    my $expected_quantity = $quantity->quantity - 1;

    note 'Send a container ready';
    $self->send_message( $self->create_message(
        ContainerReady   => {
            container_id => $container_id,
            allocations  => [ { allocation_id => $allocation->id } ],
            prl          => "Full",
        }
    ) );

    # Re-read $quantity from db
    $quantity->discard_changes;

    # We should have decremented the quantity by one.
    is($quantity->quantity, $expected_quantity);

    note 'Send another container ready';
    $self->send_message( $self->create_message(
        ContainerReady   => {
            container_id => $container_id,
            allocations  => [ { allocation_id => $allocation->id } ],
            prl          => "Full",
        }
    ) );

    # Re-read $quantity from db
    $quantity->discard_changes;

    # Quantity shouldn't have changed
    is($quantity->quantity, $expected_quantity);
}

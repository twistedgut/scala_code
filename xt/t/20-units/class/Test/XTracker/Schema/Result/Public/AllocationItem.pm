package Test::XTracker::Schema::Result::Public::AllocationItem;
use NAP::policy "tt", qw/test class/;
BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::WithSchema';
};
use Carp;
use FindBin::libs;

use Test::XT::Data::IntegrationContainer;
use Test::XT::Fixture::Fulfilment::Shipment;

# Allocation items only exist with PRLs - this is a unit test, however - so
# really it should 'do the right thing' even without PRLs (see
# http://jira4.nap/browse/DCA-1989).
use Test::XTracker::RunCondition prl_phase => 'prl';

=head1 NAME

Test::XTracker::Schema::Result::Public::AllocationItem - Unit tests for
XTracker::Schema::Result::Public::AllocationItem

=head1 DESCRIPTION

Unit tests for XTracker::Schema::Result::Public::AllocationItem

=head1 SYNOPSIS

 # Run all tests
 prove t/20-units/class/Test/XTracker/Schema/Result/Public/AllocationItem.pm

 # Run all tests matching the foo_bar regex
 TEST_METHOD=foobar prove t/20-units/class/Test/XTracker/Schema/Result/Public/AllocationItem.pm

 # For more details, perldoc NAP::Test::Class

=cut

use XTracker::Constants::FromDB qw/
    :container_status
/;

sub add_to_integration_container : Tests {

    # Create a picked GOH shipment with 1 item
    my $goh_fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            'GOH'  => 1,
        },
    })->with_picked_shipment;
    # Create a new container to integrate into
    my ($integration_container) = Test::XT::Data::IntegrationContainer->create_new_integration_containers({
        how_many => 1,
    });

    # Now for some testing
    note "Test adding an item to a container";
    is ($integration_container->integration_container_items->count, 0,
        "initially, integration container is empty");
    is ($integration_container->container->status_id, $PUBLIC_CONTAINER_STATUS__AVAILABLE,
        "and container status is available");

    my $allocation_item = $goh_fixture->shipment_row->shipment_items->first->allocation_items->first;
    my $initial_container_id = $allocation_item->shipment_item->container_id;
    lives_ok( sub {
            $allocation_item->add_to_integration_container({
                integration_container => $integration_container
            });
        },
        "add_to_integration_container lives"
    );
    is ($integration_container->integration_container_items->count, 1,
        "integration container now has one item in it...");
    ok(
        $integration_container->integration_container_items->first->is_integrated,
        '... Item in integration container is in Integrated status...');
    is ($integration_container->integration_container_items->first->allocation_item_id,
        $allocation_item->id,
        "... and it's the right item");
    is ($integration_container->container->status_id, $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
        "container row has correct status");
    isnt ($allocation_item->shipment_item->container_id, $initial_container_id,
        "shipment item is no longer in original container");
    is ($allocation_item->shipment_item->container_id, $integration_container->container_id,
        "shipment item has been put into the integration container");
}

sub add_missing_to_integration_container : Tests {

    # Create a picked GOH shipment with 1 item
    my $goh_fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            'GOH'  => 1,
        },
    })->with_picked_shipment;

    # Create a new container to integrate into
    my ($integration_container) = Test::XT::Data::IntegrationContainer->create_new_integration_containers({
        how_many => 1,
    });

    # Mark item as Missing one
    my $allocation_item = $goh_fixture->shipment_row->shipment_items->first->allocation_items->first;
    my $initial_container_id = $allocation_item->shipment_item->container_id;
    $allocation_item->add_to_integration_container({
        integration_container => $integration_container,
        is_missing            => 1,
    });
    ok(
        $integration_container->integration_container_items->first->is_missing,
        'Check that item has Missing status.'
    );
}

sub validate_add_to_integration_container : Tests {

    # Create 3 GOH-only single-item shipments, a GOH-only multi-item
    # shipment, and a mixed-PRL shipment with only one GOH item. Ensure
    # all shipments have been picked.
    my $single_item_goh_1 = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            'GOH'  => 1,
        },
    })->with_picked_shipment;
    my $single_item_goh_2 = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            'GOH'  => 1,
        },
    })->with_picked_shipment;
    my $single_item_goh_3 = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            'GOH'  => 1,
        },
    })->with_picked_shipment;
    my $multi_item_goh = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            'GOH'  => 3,
        },
    })->with_picked_shipment;
    my $mixed = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            'GOH'  => 1,
            'Full' => 1,
        },
    })->with_picked_shipment;

    # Create some totes to use for integration
    my (@integration_containers) = Test::XT::Data::IntegrationContainer->create_new_integration_containers({
        how_many => 3,
        prefix   => 'T4',
    });
    note "Test that two single-item shipments can be combined";
    my $allocation_item_1 = $single_item_goh_1->shipment_row->shipment_items->first->allocation_items->first;
    $allocation_item_1->add_to_integration_container({
        integration_container => $integration_containers[0]
    });
    my $allocation_item_2 = $single_item_goh_2->shipment_row->shipment_items->first->allocation_items->first;
    lives_ok( sub {
            $allocation_item_2->add_to_integration_container({
                integration_container => $integration_containers[0]
            });
        },
        "add_to_integration_container lives"
    );
    is ($integration_containers[0]->integration_container_items->count, 2,
        "integration container now has two items in it");

    note "Try adding the same item to the same container again";
    throws_ok( sub {
            $allocation_item_2->add_to_integration_container({
                integration_container => $integration_containers[0]
            });
        },
        qr/This item is already in container.*${\$integration_containers[0]->container_id}.*resume/,
        "add_to_integration_container dies, user is told item already in container"
    );
    is ($integration_containers[0]->integration_container_items->count, 2,
        "integration container still has two items in it");

    note "Try adding the same item to a different container";
    throws_ok( sub {
            $allocation_item_2->add_to_integration_container({
                integration_container => $integration_containers[1]
            });
        },
        qr/This item is already in container.*${\$integration_containers[0]->container_id}.*resume/,
        "add_to_integration_container dies, user is told item already in container"
    );
    is ($integration_containers[1]->integration_container_items->count, 0,
        "new integration container has no items in it");

    note "Try adding the same item to a different container when its original one has been completed";
    # Temporarily pretend our first container has been completed
    $integration_containers[0]->update({
        is_complete => 1,
    });
    throws_ok( sub {
            $allocation_item_2->add_to_integration_container({
                integration_container => $integration_containers[1]
            });
        },
        qr/This item has already been sent to packing in container.*${\$integration_containers[0]->container_id}/,
        "add_to_integration_container dies, user is told item has already gone to packing"
    );

    note "Try adding a new item to a completed container";
    my $allocation_item_3 = $single_item_goh_3->shipment_row->shipment_items->first->allocation_items->first;
    throws_ok( sub {
            $allocation_item_3->add_to_integration_container({
                integration_container => $integration_containers[0]
            });
        },
        qr/Container \[${\$integration_containers[0]->container_id}\] has already been completed/,
        "add_to_integration_container dies, user is told container is complete"
    );
    # Uncomplete $integration_containers[0] so we can use it for more tests
    $integration_containers[0]->update({
        is_complete => 0,
    });

    note "Test that a multi-item shipment can't be combined with others, but can go it its own container";
    my $allocation_item_multi = $multi_item_goh->shipment_row->shipment_items->first->allocation_items->first;
    # Try adding to the container that already has two single-item shipments in it
    throws_ok( sub {
            $allocation_item_multi->add_to_integration_container({
                integration_container => $integration_containers[0]
            });
        },
        qr/This is a shipment with multiple items and this tote already contains at least one other shipment/,
        "add_to_integration_container dies, user is told container has other shipments"
    );
    lives_ok( sub {
            $allocation_item_multi->add_to_integration_container({
                integration_container => $integration_containers[2]
            });
        },
        "add_to_integration_container lives when a new container is used"
    );

    note "Test that a multi-item shipment can't be combined with others, even if the GOH PRL part only had one item";
    my $allocation_item_mixed = $mixed->shipment_row->shipment_items->first->allocation_items->first;
    throws_ok( sub {
            $allocation_item_mixed->add_to_integration_container({
                integration_container => $integration_containers[0]
            });
        },
        qr/This is a shipment with multiple items and this tote already contains at least one other shipment/,
        "add_to_integration_container dies, user is told container has multi-item shipment"
    );

}

=head1 SEE ALSO

L<NAP::Test::Class>

L<XTracker::Schema::ResultSet::Public::AllocationItem>

=cut

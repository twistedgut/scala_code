package Test::XTracker::Schema::Result::IntegrationContainer;

use NAP::policy "test", "class";
use FindBin::libs;
use Test::XTracker::RunCondition prl_phase => 2;
use Test::XTracker::LoadTestConfig;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::WithGOHIntegration';
}

use Guard;
use Test::XTracker::MessageQueue;
use Test::XTracker::Data::PackRouteTests;
use XTracker::Config::Local qw/config_var/;
use Test::XT::Data::Container;
use XT::Data::Fulfilment::GOH::Integration;
use XTracker::Constants::FromDB qw/
    :prl_delivery_destination
    :pack_lane_attribute
/;
use vars qw/
    $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
    $PRL_DELIVERY_DESTINATION__GOH_DIRECT
/;

=head2 mark_as_complete

The idea of this test is: for allocation with two items
integrate each item into separate container and check
when the allocation changes its state from Delivered.
After first item is integrated allocation is still Delivered.
After second went into container allocation changes its status

=cut

sub mark_as_complete :Tests {
    my $self = shift;

    my $allocation_item = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
            { items_quantity => 2 }
        );

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_direct
    });

    note 'Integrate first SKU';
    my $sku = $allocation_item->shipment_item->get_sku;
    my ($container) = Test::XT::Data::Container->create_new_container_rows;
    $process->set_container( $container->id );
    $process->set_sku( $sku );
    $process->commit_scan;

    my $integration_container = $process->integration_container_row;
    $integration_container->mark_as_complete;


    note 'Check that related Integration container is updated';
    $integration_container->discard_changes;
    ok
        $integration_container->is_complete,
        'is_complete flag is set to be true';
    ok
        $integration_container->completed_at,
        'completed_at is set';


    my $allocation = $integration_container->allocation_items
        ->first->allocation;
    ok
        $allocation->is_delivered,
        'Allocation is still in Delivered status as it has item waiting to be integrated';


    note 'Integrate second item from allocation';
    my @items = $allocation->allocation_items;
    $sku = $items[1]->shipment_item->get_sku;
    ($container) = Test::XT::Data::Container->create_new_container_rows;
    $process->set_container( $container->id );
    $process->set_sku( $sku );
    $process->commit_scan;

    $integration_container = $process->integration_container_row;
    $integration_container->mark_as_complete;
    $integration_container->discard_changes;

    $allocation = $integration_container->allocation_items
            ->first->allocation;

    ok
        !$allocation->is_delivered,
        'Allocation is not Delivered anymore';
}

sub allocation_items :Tests {
    my $self = shift;

    my $allocation_item = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
            { items_quantity => 2 }
        );

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_direct
    });

    my ($container) = Test::XT::Data::Container->create_new_container_rows;
    $process->set_container( $container->id );

    is
        $process->integration_container_row->allocation_items->count,
        0,
        'Integration container is empty';

    $process->set_sku( $allocation_item->shipment_item->get_sku );
    $process->commit_scan;


    $process->integration_container_row->discard_changes;

    is
        $process->integration_container_row->allocation_items->count,
        1,
        'Integration container is empty';
}

=head2 mark_as_complete__consider_incomplete_integrated_peers

The idea of the test is to get an allocation with 2 items
place one item into one integration container, but do not
mark it as complete, and then place second item into
another container and check that main allocation does not
change its status as both its items are not completely
integrated.

=cut

sub mark_as_complete__consider_incomplete_integrated_peers :Tests {
    my $self = shift;

    my $allocation_item = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
            { items_quantity => 2 }
        );

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_direct
    });

    note 'Place first SKU into integration container';
    my $sku = $allocation_item->shipment_item->get_sku;
    my ($container) = Test::XT::Data::Container->create_new_container_rows;
    $process->set_container( $container->id );
    $process->set_sku( $sku );
    $process->commit_scan;

    my $allocation =$process->integration_container_row->allocation_items
        ->first->allocation;
    ok
        $allocation->is_delivered,
        'Allocation is still in Delivered status as it has item waiting to be integrated';


    note 'Place second item into another container';
    my @items = $allocation->allocation_items;
    $sku = $items[1]->shipment_item->get_sku;
    ($container) = Test::XT::Data::Container->create_new_container_rows;
    $process->set_container( $container->id );
    $process->set_sku( $sku );
    $process->commit_scan;

    my $integration_container = $process->integration_container_row;

    note 'And mark second container as complete';
    $integration_container->mark_as_complete;
    $integration_container->discard_changes;

    $allocation = $integration_container->allocation_items
        ->first->allocation;

    ok
        $allocation->is_delivered,
        'Allocation is still Delivered as first item although '
            . 'in integration container but not in completed one';
}

=head2 check_route_request_message_is_sent_after_integration

Check that after container is integrated at either Direct or
Integration lane a route request is sent with destination to
pack lane.

=cut

sub check_route_request_message_is_sent_after_integration :Tests {
    my $self = shift;

    note 'Set Pack lanes capacities to have just ONE lane pack_lane_3 '
        .'so anything that is routed to Packing goes only to that lane';
    my $plt = Test::XTracker::Data::PackRouteTests->new;
    $plt->reset_and_apply_config([
        {
            pack_lane_id  => 3,
            human_name    => 'pack_lane_3',
            capacity      => 1000,
            internal_name => 'DA.PO01.0000.CCTA01NP09',
            active        => 1,
            attributes    => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
        }
    ]);

    # make sure that we leave Pack lanes in pristine state
    my $plt_guard = guard {
        $plt->reset_and_apply_config($plt->like_live_packlane_configuration);
    };

    subtest "Integrate container at $_ lane" =>
    sub {
        my $allocation_item = $self
            ->create_allocation_item_at_delivery_destination(
                {
                    integration => $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
                    direct => $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
                }->{$_}
            );

        my $params_method = "process_constructor_params_$_";
        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->$params_method
        });

        my $sku = $allocation_item->shipment_item->get_sku;
        my ($container) = Test::XT::Data::Container->create_new_container_rows;

        ok(
            !$container->pack_lane_id,
            'Make sure contianer does not have any pack lanes assigned'
        );

        $process->set_container( $container->id );
        $process->set_sku( $sku );
        $process->commit_scan;

        note 'Start monitoring message queue';
        my $message_queue = Test::XTracker::MessageQueue->new;
        my $message_destination = config_var(PRL => 'conveyor_queue')
            or fail('Could not find queue in config');
        $message_queue->clear_destination($message_destination);


        $process->integration_container_row->mark_as_complete;

        $message_queue->assert_messages(
            {
                destination  => $message_destination,
                assert_body => superhashof({
                    '@type'      => 'route_request',
                    container_id => $process->container_id->as_id,
                    # as a result of test setup container is always
                    # routed to pack lane 3
                    destination  => 'DA.PO01.0000.CCTA01NP09',
                }),
            },
            'route_request has been sent to packing'
        );

        $container->discard_changes;
        ok(
            $container->pack_lane_id,
            'Pack lane is assigned to routed container'
        );
    } for qw/direct integration/;
}

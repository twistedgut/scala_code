package Test::XT::DC::Messaging::Plugins::PRL::RouteResponse;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};
use Test::XTracker::RunCondition prl_phase => 'prl';

=head1 NAME

Test::XT::DC::Messaging::Plugins::PRL::RouteResponse - Unit tests for XT::DC::Messaging::Plugins::PRL::RouteResponse

=cut

use XT::DC::Messaging::Plugins::PRL::RouteResponse;
use XTracker::Constants qw/
        :application
        :prl_type
    /;
use Test::XT::Data;
use Test::XT::Data::Container;
use Test::XT::Data::IntegrationContainer;
use Test::XTracker::Data;
use XT::DC::Messaging::Plugins::PRL::PrepareResponse;
use XTracker::Constants::FromDB qw/
    :container_status
    :allocation_item_status
    :allocation_status
    :prl_delivery_destination
    :prl
    :shipment_item_status
    :storage_type
    :pws_action
    :customer_issue_type
/;

use Test::XTracker::Artifacts::RAVNI;

use Test::XTracker::RunCondition prl_phase => 2;
use XTracker::Constants::FromDB ':prl';
use vars qw/$PRL__DEMATIC $PRL__GOH/;

our ($PRL_DELIVERY_DESTINATION__GOH_DIRECT, $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION);

use Test::XTracker::Data::PackRouteTests;

sub startup :Tests(startup) {
    my $self = shift;

    my $pack_route_test = Test::XTracker::Data::PackRouteTests->new();
    $pack_route_test->reset_and_apply_config(
        $pack_route_test->like_live_packlane_configuration(),
    );
}

sub test__handler__happy_path : Tests() {
    my $self = shift;

    # Setup
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        how_many           => 1,
        status             => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
        with_shipment_item => 1,
    });
    $self->search_one(Container => { id => $container_id })->update({
        pack_lane_id => $self->rs("PackLane")->first->id,
    });

    my $reason = 'Test reason #'.int(rand 1000);

    # Send a message
    $self->send_and_test_log( {
        container_id => $container_id,
        location     => 'foo',
        success      => $PRL_TYPE__BOOLEAN__TRUE,
        reason       => $reason,
    } );

    # Make sure has_arrived flag is turned on for container and arrival time recorded
    my $container = $self->schema->resultset('Public::Container')->find($container_id);
    ok( $container->has_arrived, 'has_arrived flag turned on for container' );
    ok( defined($container->arrived_at), 'arrived_at set for container' );
}

# TODO DCA-2272: new test that sets success to false, after we've defined what should
# happen in that case.

sub test__handler__missing_pack_lane : Tests() {
    my $self = shift;

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        how_many           => 1,
        status             => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
        with_shipment_item => 1,
    });
    my $container = $self->search_one(Container => { id => $container_id });

    ok ( !$container->pack_lane_id, "New container doesn't have a pack lane set" );

    $self->send_and_test_log( {
        container_id => $container_id,
        location     => 'foo',
        success      => $PRL_TYPE__BOOLEAN__TRUE,
        reason       => "No reason",
    } );
    ok( !$container->has_arrived, 'has_arrived flag not turned on' );
}

sub send_and_test_log {

    my ($self, $message_fields) = @_;

    # Get ID of last message
    my $message_id = $self->schema->resultset('Public::ActivemqMessage')->get_column('id')->max;

    $self->send_message(
        $self->create_message(
            RouteResponse => $message_fields
        )
    );

    # Check for new entry in message log
    my $logged_message = $message_id
        ? $self->schema->resultset('Public::ActivemqMessage')->find( ++$message_id ) # there are previous entries
        : $self->schema->resultset('Public::ActivemqMessage')->first; # this will be the first entry
    is( $logged_message->entity_id, $message_fields->{container_id}, 'Message was logged' );
    like(
        $logged_message->content,
        qr/$message_fields->{reason}/,
        'Message failure reason logged correctly',
    );
    unlike(
        $logged_message->content,
        qr/:null,/,
        'No null fields in logged message',
    );
    is( $logged_message->message_type,
        'route_response',
        'Message type logged correctly' );

}

sub test__handler__carton : Tests() {
    my $self = shift;

    my $carton_id = 'C1642657';

    my $reason = 'Test carton route response';

    # Send a message
    $self->send_and_test_log( {
        container_id => $carton_id,
        location     => 'foo',
        success      => $PRL_TYPE__BOOLEAN__TRUE,
        reason       => $reason,
    } );

    note "Nothing else happens when we get a route_response for a carton, so as long as we logged it we're fine";

}

sub test__handler__arrived_at_integration : Tests {
    my $self = shift;

    my ($integration_container) =
        Test::XT::Data::IntegrationContainer->create_new_integration_containers({
            how_many           => 1,
            with_shipment_item => 1,
        });

    my $integration_location_id = 'DA.GH01.0000.GOH_01';

    note "Container is routed to integration and arrives there";
    Test::XT::Data::IntegrationContainer->route_to_integration(
        integration_container => $integration_container
    );

    is ($integration_container->arrived_at, undef,
        "container has not arrived at integration");
    my $reason = 'Test reason #'.int(rand 1000);
    # Send a message
    $self->send_and_test_log( {
        container_id => $integration_container->container_id,
        location     => $integration_location_id,
        success      => $PRL_TYPE__BOOLEAN__TRUE,
        reason       => $reason,
    } );
    $integration_container->discard_changes;
    isnt ($integration_container->arrived_at, undef,
        "container is now at integration");

}

sub test__deliver_sent_to_goh_on_route_response :Tests() {
    my $self = shift;

    my $fixture = $self->create_preparing_allocation(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
        'with_dcd',
    );
    my $allocation = $fixture->{goh_allocation};
    my $dcd_allocation = $fixture->{dcd_allocation};

    note "Start picking the DCD allocation";
    my $integration_container = $self->pick_and_route($dcd_allocation);

    note "Send prepare response before the DCD pick has been completed, and check that deliver is not sent";
    my $prepare_response_message = $self->create_prepare_response_message($allocation);

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    lives_ok( sub { $self->send_message( $prepare_response_message ) },
        'prepare_response message sent');

    $xt_to_prl->expect_no_messages();

    $allocation->discard_changes;
    is ($allocation->status_id, $ALLOCATION_STATUS__PREPARED,
        'Allocation status updated to "prepared"');

    # now simulate a route request.
    note "Send route_response to indicate the container has arrived at integration";
    $self->send_message(
        $self->create_route_response_message(
            $integration_container->container_id,
            'DA.GH01.0000.GOH_01' # GOH integration lane
        )
    );

    # expect a deliver message to have been sent.
    $xt_to_prl->expect_messages({
        messages => [{
            type    => 'deliver',
            path    => $allocation->prl->amq_queue,
            details => {
                allocation_id => $allocation->id,
            },
        }],
    });

    $allocation->discard_changes;
    is ($allocation->status_id, $ALLOCATION_STATUS__DELIVERING,
        'Allocation status updated to "delivering"');

}

# if we do a size change on a goh item it abandons the allocation
# and starts a new one. This could leave prepared items sitting
# around in an MTS primary buffer forever. lets make sure we
# eject _multiple_ goh allocations if there are some.

sub test_deliver_sent_to_multiple_gohs_on_route_response :Tests() {
    my $self = shift;

    my $fixture = $self->create_preparing_allocation(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
        'with_dcd',
    );

    my $first_goh_allocation = $fixture->{goh_allocation};
    my $dcd_allocation = $fixture->{dcd_allocation};

    # Add another allocation...
    my $second_goh_allocation = $self->create_preparing_allocation(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
    )->{'goh_allocation'};

    $second_goh_allocation->update({
        shipment_id => $first_goh_allocation->shipment_id
    });

    # cancel first (not that impacts prl)
    $_->cancel({
        operator_id            => $APPLICATION_OPERATOR_ID,
        customer_issue_type_id => $CUSTOMER_ISSUE_TYPE__8__SIZE_CHANGE,
        pws_action_id          => $PWS_ACTION__SIZE_CHANGE,
        notes                  => "Size change on allocation ". $first_goh_allocation->id,
        stock_manager          => $first_goh_allocation->shipment->order->channel->stock_manager,
        no_allocate            => 1,
    }) foreach($first_goh_allocation->shipment->shipment_items);

    # end of setup

    note "Start picking the DCD allocation";
    my $integration_container = $self->pick_and_route($dcd_allocation);

    note "Send prepare response before the DCD pick has been completed, and check that deliver is not sent";
    my $first_prepare_response_message = $self->create_prepare_response_message($first_goh_allocation);
    my $second_prepare_response_message = $self->create_prepare_response_message($second_goh_allocation);

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    lives_ok( sub {
        $self->send_message( $first_prepare_response_message );
        $self->send_message( $second_prepare_response_message );
        },
        'multiple prepare_response messages sent ok'
    );

    $xt_to_prl->expect_no_messages();

    $first_goh_allocation->discard_changes;
    $second_goh_allocation->discard_changes;

    is ($first_goh_allocation->status_id, $ALLOCATION_STATUS__PREPARED,
        'First GOH allocation status updated to "prepared"');

    is ($second_goh_allocation->status_id, $ALLOCATION_STATUS__PREPARED,
        'Second GOH allocation status updated to "prepared"');

    # now simulate a route request.
    note "Send route_response to indicate the container has arrived at integration";
    $self->send_message(
        $self->create_route_response_message(
            $integration_container->container_id,
            'DA.GH01.0000.GOH_01' # GOH integration lane
        )
    );

    # expect a deliver message to have been sent.
    $xt_to_prl->expect_messages({
        messages => [{
            type    => 'deliver',
            path    => $first_goh_allocation->prl->amq_queue,
            details => {
                allocation_id => $first_goh_allocation->id,
            },
        }, {
            type    => 'deliver',
            path    => $second_goh_allocation->prl->amq_queue,
            details => {
                allocation_id => $second_goh_allocation->id,
            },
        }],
    });

    $first_goh_allocation->discard_changes;
    $second_goh_allocation->discard_changes;

    is ($first_goh_allocation->status_id, $ALLOCATION_STATUS__DELIVERING,
        'First allocation status updated to "delivering"');

    is ($second_goh_allocation->status_id, $ALLOCATION_STATUS__DELIVERING,
        'Second allocation status updated to "delivering"');

}

=head1 DATA SETUP METHODS

=head2 create_preparing_allocation

TODO: Largely copied from create_delivering_allocation
Test::XT::DC::Messaging::Plugins::PRL::DeliverResponse
Should probably combine them in some way.

Can create a DCD allocation too, if second param is set.

Returns hashref of GOH allocation, DCD allocation (may be
undef) and shipment.

=cut

sub create_preparing_allocation {
    my $self = shift;
    my ($delivery_destination, $with_dcd) = @_;

    $delivery_destination //= $PRL_DELIVERY_DESTINATION__GOH_DIRECT;

    # Create an order with two hanging items
    my $data = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );

    my @goh_pids = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__HANGING,
        how_many => 1,
    });
    my @shipment_pids = @goh_pids;
    if ($with_dcd) {
        my @dcd_pids = Test::XTracker::Data->create_test_products({
            storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
            how_many => 2,
        });
        push @shipment_pids, @dcd_pids;
    }
    my $shipment = $data->new_order( products => \@shipment_pids )
        ->{'shipment_object'};

    if ($with_dcd) {
        is ($shipment->allocations->count, 2, "Shipment has 2 allocations");
    } else {
        is ($shipment->allocations->count, 1, "Shipment has 1 allocation");
    }

    my $goh_allocation = $shipment->allocations->search({
        'prl_id' => $PRL__GOH,
    })->first;
    my $dcd_allocation = $shipment->allocations->search({
        'prl_id' => $PRL__DEMATIC,
    })->first;

    # Pretend the PRL has picked everything in GOH and XT has
    # sent the prepare message
    $goh_allocation->allocation_items->related_resultset('shipment_item')->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED
    });
    $goh_allocation->allocation_items->update({
        status_id => $ALLOCATION_ITEM_STATUS__PICKED
    });
    $goh_allocation->update({
        status_id        => $ALLOCATION_STATUS__PREPARING,
        prl_delivery_destination_id => $delivery_destination,
    });

    return {
        'goh_allocation' => $goh_allocation,
        'dcd_allocation' => $dcd_allocation,
        'shipment'       => $shipment,
    };
}

=head2 create_prepare_response_message ($allocation, %overrides) : $prepare_response_message

TODO: Largely copied from create_deliver_response_message
Test::XT::DC::Messaging::Plugins::PRL::DeliverResponse
Should probably combine them in some way.

=cut

sub create_prepare_response_message {
    my ($self, $allocation, %overrides) = @_;

    # Setup a deliver_response message
    my $prepare_response_message = $self->create_message(
        PrepareResponse => {
            allocation_id => $allocation->id,
            success       => $PRL_TYPE__BOOLEAN__TRUE,
            reason        => '',
            prl           => $allocation->prl->amq_identifier,
            %overrides,
        }
    );

    return $prepare_response_message;
}


sub create_route_response_message {
    my $self = shift;
    my ($container_id, $location) = @_;

    # Setup a deliver_response message
    my $route_response_message = $self->create_message(
        RouteResponse => {
            container_id => $container_id,
            success      => $PRL_TYPE__BOOLEAN__TRUE,
            reason       => '',
            location     => $location,
            prl          => 'dcd'
        }
    );

    return $route_response_message;
}

=head2 pick_and_route ($dcd_allocation) : $integration_container

Picks the supplied DCD allocation and returns the integration container
that's created when container_ready is received.

=cut

sub pick_and_route {
    my $self = shift;
    my ($dcd_allocation) = @_;

    $dcd_allocation->pick(Test::XTracker::MessageQueue->new, 1);
    my $container_id = Test::XT::Data::Container->get_unique_id();

    # Send ItemPicked messages
    $self->send_message( $self->create_message(
        ItemPicked => {
            allocation_id => $dcd_allocation->id,
            client        => $_->shipment_item->variant->prl_client,
            pgid          => 'p12345',
            user          => "Prepare Response Test",
            sku           => $_->shipment_item->variant->sku,
            container_id  => $container_id->as_id,
            prl           => "dcd",
        }
    ) ) for $dcd_allocation->allocation_items;

    # Send ContainerReady message
    $self->send_message( $self->create_message(
        ContainerReady => {
            container_id => $container_id->as_id,
            allocations  => [ { allocation_id => $dcd_allocation->id } ],
            prl          => "dcd",
        }
    ) );

    # Send PickComplete message
    $self->send_message( $self->create_message(
        PickComplete => {
            allocation_id => $dcd_allocation->id,
            prl           => "dcd",
        }
    ) );

    # Sanity check - allocation is picked and integration container
    # has been created
    $dcd_allocation->discard_changes;
    is ($dcd_allocation->status_id, $ALLOCATION_STATUS__PICKED, "DCD allocation has been picked");
    my $integration_container_rs = $self->schema->resultset('Public::IntegrationContainer')->search({
        container_id => $container_id->as_id
    });
    is ($integration_container_rs->count, 1, "One integration container has been made");
    my $integration_container = $integration_container_rs->first;

    return $integration_container;
}

1;

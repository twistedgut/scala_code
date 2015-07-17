package Test::XT::DC::Messaging::Plugins::PRL::PrepareResponse;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};

use Test::XT::Data;
use Test::XTracker::Data;
use XT::DC::Messaging::Plugins::PRL::PrepareResponse;
use XTracker::Constants::FromDB qw/
    :allocation_status
    :allocation_item_status
    :prl_delivery_destination
    :prl
    :shipment_item_status
    :storage_type
/;
use XTracker::Constants qw /:prl_type/;
use vars qw/$PRL__GOH $PRL__DEMATIC/;
use Test::XTracker::Artifacts::RAVNI;

use Test::XTracker::RunCondition prl_phase => 2;

our ($PRL_DELIVERY_DESTINATION__GOH_DIRECT, $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION);

=head1 NAME

Test::XT::DC::Messaging::Plugins::PRL::PrepareResponse

=head1 DESCRIPTION

Unit tests for XT::DC::Messaging::Plugins::PRL::PrepareResponse

=head1 TESTS

=head2 basic_prepare_response_success

Test basic prepare_response message for shipment with 1 GOH item,
check that handler completes successfully and deliver message is
sent.

=cut

sub test__basic_prepare_response_success : Tests() {
    my $self = shift;

    my $fixture = $self->create_preparing_allocation;
    my $allocation = $fixture->{goh_allocation};

    is($allocation->status_id, $ALLOCATION_STATUS__PREPARING,
       'Allocation status starts as "preparing"');

    my $prepare_response_message = $self->create_prepare_response_message($allocation);

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    lives_ok( sub { $self->send_message( $prepare_response_message ) },
        'prepare_response message sent');

    # In the 1 GOH Item scenario, prepare_response automatically sends
    # the deliver message
    $xt_to_prl->expect_messages({
         messages => [ {
             type    => 'deliver',
             path    => $allocation->prl->amq_queue,
             details => {
                 allocation_id => $allocation->id,
             },
         } ],
    });

    # re-read from database
    $allocation->discard_changes;
    # In the '1 GOH Item' scenario, the 'deliver' message
    # is sent as soon as the 'prepare_response' is received.
    # Therefore the status won't be 'prepared', but 'delivering'.
    is ($allocation->status_id, $ALLOCATION_STATUS__DELIVERING,
        'Allocation status updated to "delivering"');
}

=head2 with_dcd_pick_complete_container_arrived

Test when DCD pick has been sent, DCD allocation has been completely
picked, DCD container has been routed to integration, and
route_response has been received indicating DCD container has
diverted to integration lane.

Deliver should be sent.

=cut

sub test__with_dcd_pick_complete_container_arrived : Tests() {
    my $self = shift;

    my $fixture = $self->create_preparing_allocation(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
        'with_dcd',
    );
    my $allocation = $fixture->{goh_allocation};
    my $dcd_allocation = $fixture->{dcd_allocation};

    note "Pick the DCD allocation into a container which is routed to integration";
    my $integration_container = $self->pick_and_route($dcd_allocation);

    note "Send route_response to indicate the container has arrived at integration";
    # Fake route_response
    $self->send_message(
        $self->create_route_response_message(
            $integration_container->container_id,
            'DA.GH01.0000.GOH_01' # GOH integration lane
        )
    );

    note "Check that deliver is sent from prepare_response";
    my $prepare_response_message = $self->create_prepare_response_message($allocation);

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    lives_ok( sub { $self->send_message( $prepare_response_message ) },
        'prepare_response message sent');

    # Deliver should be sent
    $xt_to_prl->expect_messages({
         messages => [ {
             type    => 'deliver',
             path    => $allocation->prl->amq_queue,
             details => {
                 allocation_id => $allocation->id,
             },
         } ],
    });

    $allocation->discard_changes;
    is ($allocation->status_id, $ALLOCATION_STATUS__DELIVERING,
        'Allocation status updated to "delivering"');
}


=head2 with_dcd_pick_complete_container_routed

Test when DCD pick has been sent, DCD allocation has been completely
picked, DCD container has been routed to integration, but the
route_response has not yet been received indicating DCD container
is still on its way.

Deliver should not be sent.

=cut

sub test__with_dcd_pick_complete_container_routed : Tests() {
    my $self = shift;

    my $fixture = $self->create_preparing_allocation(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
        'with_dcd',
    );
    my $allocation = $fixture->{goh_allocation};
    my $dcd_allocation = $fixture->{dcd_allocation};

    note "Pick the DCD allocation into a container which is routed to integration";
    my $integration_container = $self->pick_and_route($dcd_allocation);

    note "Check that deliver is not sent from prepare_response, because we're still waiting for the container to arrive at integration";
    my $prepare_response_message = $self->create_prepare_response_message($allocation);

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    lives_ok( sub { $self->send_message( $prepare_response_message ) },
        'prepare_response message sent');

    $xt_to_prl->expect_no_messages();

    $allocation->discard_changes;
    is ($allocation->status_id, $ALLOCATION_STATUS__PREPARED,
        'Allocation status updated to "prepared"');
}


=head2 with_dcd_pick_not_started

Test when DCD pick has not yet been sent.

Deliver should not be sent.

=cut

sub test__with_dcd_pick_not_started : Tests() {
    my $self = shift;

    my $fixture = $self->create_preparing_allocation(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
        'with_dcd',
    );
    my $allocation = $fixture->{goh_allocation};
    my $dcd_allocation = $fixture->{dcd_allocation};

    note "Send prepare response before the DCD pick has even been sent, and check that deliver is not sent";
    my $prepare_response_message = $self->create_prepare_response_message($allocation);

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    lives_ok( sub { $self->send_message( $prepare_response_message ) },
        'prepare_response message sent');

    $xt_to_prl->expect_no_messages();

    $allocation->discard_changes;
    is ($allocation->status_id, $ALLOCATION_STATUS__PREPARED,
        'Allocation status updated to "prepared"');
}


=head2 with_dcd_picking_in_progress

Test when DCD pick has been sent and picking is still in progress.

Deliver should not be sent.

=cut

sub test__with_dcd_picking_in_progress : Tests() {
    my $self = shift;

    my $fixture = $self->create_preparing_allocation(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
        'with_dcd',
    );
    my $allocation = $fixture->{goh_allocation};
    my $dcd_allocation = $fixture->{dcd_allocation};

    note "Start picking the DCD allocation";
    $dcd_allocation->pick(Test::XTracker::MessageQueue->new, 1);

    note "Send prepare response before the DCD pick has been completed, and check that deliver is not sent";
    my $prepare_response_message = $self->create_prepare_response_message($allocation);

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    lives_ok( sub { $self->send_message( $prepare_response_message ) },
        'prepare_response message sent');

    $xt_to_prl->expect_no_messages();

    $allocation->discard_changes;
    is ($allocation->status_id, $ALLOCATION_STATUS__PREPARED,
        'Allocation status updated to "prepared"');
}


=head2 with_dcd_pick_complete_short_pick

Test when DCD allocation is short picked.

Deliver should be sent.

=cut

sub test__with_dcd_pick_complete_short_pick : Tests() {
    my $self = shift;

    my $fixture = $self->create_preparing_allocation(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
        'with_dcd',
    );
    my $allocation = $fixture->{goh_allocation};
    my $dcd_allocation = $fixture->{dcd_allocation};

    note "Short pick the DCD allocation";
    $dcd_allocation->pick(Test::XTracker::MessageQueue->new, 1);
    $self->send_message( $self->create_message(
        PickComplete => {
            allocation_id => $dcd_allocation->id,
            prl           => "dcd",
        }
    ) );

    note "Check that deliver is sent from prepare_response, because nothing else will happen with the short picked DCD allocation";
    my $prepare_response_message = $self->create_prepare_response_message($allocation);

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    lives_ok( sub { $self->send_message( $prepare_response_message ) },
        'prepare_response message sent');

    $xt_to_prl->expect_messages({
         messages => [ {
             type    => 'deliver',
             path    => $allocation->prl->amq_queue,
             details => {
                 allocation_id => $allocation->id,
             },
         } ],
    });

    $allocation->discard_changes;
    is ($allocation->status_id, $ALLOCATION_STATUS__DELIVERING,
        'Allocation status updated to "delivering"');
}

=head2 with_dcd_cancelled

Test that deliver is sent when dcd sibling cancelled.

=cut

sub with_dcd_cancelled :Tests {
    my $self = shift;

    my $fixture = $self->create_preparing_allocation(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION,
        'with_dcd',
    );
    my $allocation = $fixture->{goh_allocation};
    my $dcd_allocation = $fixture->{dcd_allocation};

    note "Cancel the DCD allocation";
    $dcd_allocation->allocation_items->update({ status_id => $ALLOCATION_ITEM_STATUS__CANCELLED });

    note "Check that deliver is sent from prepare_response, because nothing else will happen with the cancelled DCD allocation";
    my $prepare_response_message = $self->create_prepare_response_message($allocation);

    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    lives_ok( sub { $self->send_message( $prepare_response_message ) },
        'prepare_response message sent');

    $xt_to_prl->expect_messages({
         messages => [ {
             type    => 'deliver',
             path    => $allocation->prl->amq_queue,
             details => {
                 allocation_id => $allocation->id,
             },
         } ],
    });

    $allocation->discard_changes;
    is ($allocation->status_id, $ALLOCATION_STATUS__DELIVERING,
        'Allocation status updated to "delivering"');

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

=head2 create_route_response_message ($container_id, $location) : $route_response_message

Returns a successful route_response message for the supplied container id
and location.

=cut

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
            prl          => 'dcd' # the only prl that sends route_response
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


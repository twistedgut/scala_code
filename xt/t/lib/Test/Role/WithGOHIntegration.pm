package Test::Role::WithGOHIntegration;

use NAP::policy 'role';

with 'Test::Role::WithDeliverResponse',
     'NAP::Test::Class::PRLMQ';

use Test::XT::Fixture::Fulfilment::Shipment;
use XTracker::Constants::FromDB qw(
    :prl_delivery_destination
    :storage_type
    :allocation_status
    :allocation_item_status
    :container_status
);
use XTracker::Constants qw(
    :prl_type
    :application
);

use vars qw/
    $PRL_DELIVERY_DESTINATION__GOH_DIRECT
    $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
/;

=head1 NAME

Test::Role::WithGOHIntegration

=head1 DESCRIPTION

Role that with helpers for tests for GOH Integration.

=head1 METHODS

=head2 create_allocation_item_at_delivery_destination

=cut

sub create_allocation_item_at_delivery_destination {
    my ($self, $destination_id, $args) = @_;

    $destination_id //= $PRL_DELIVERY_DESTINATION__GOH_DIRECT;
    $args //= {};

    my $data_helper = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );
    my $shipment = $data_helper
        ->picked_order( products => [
            map {
                Test::XTracker::Data->create_test_products({
                    storage_type_id => $PRODUCT_STORAGE_TYPE__HANGING
                })
            } 1..($args->{items_quantity} // 1)
        ])
        ->{order_object}
        ->get_standard_class_shipment;
    my $allocation = $shipment->allocations->single;
    $allocation->update({
        status_id => $ALLOCATION_STATUS__DELIVERING,
    });

    my $message_data = $self->deliver_response_payload(
        $allocation,
        { destination_id => $destination_id }
    );
    $allocation->mark_as_delivered($message_data, $APPLICATION_OPERATOR_ID);

    $allocation->discard_changes;

    return $allocation->allocation_items->first;
}

sub _process_constructor_params {
    my ($self, $delivery_destination_id) = @_;

    return
        prl_delivery_destination_row
            =>
        $self->schema
            ->resultset('Public::PrlDeliveryDestination')
            ->find($delivery_destination_id);
}

sub process_constructor_params_direct {
    $_[0]->_process_constructor_params(
        $PRL_DELIVERY_DESTINATION__GOH_DIRECT
    );
}

sub process_constructor_params_integration {
    $_[0]->_process_constructor_params(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
    );
}

sub create_dcd_integration_container_to_be_integrated {
    my $self = shift;

    my $dcd_and_goh_fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            GOH     => 2,
            Dematic => 1,
        },
    })
    ->with_prepared_goh_allocation;


    # DCD allocation came from Dematic and ready at GOH Integration DCD containers queue
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        status => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
    });
    $dcd_and_goh_fixture->dematic_allocation_row->update({
        status_id => $ALLOCATION_STATUS__PICKING,
    });
    foreach my $allocation_item ($dcd_and_goh_fixture->dematic_allocation_row->allocation_items) {
        $allocation_item->update({
            status_id   => $ALLOCATION_ITEM_STATUS__PICKED,
            picked_into => $container_id,
        });
    }
    $self->send_message( $self->create_message(
        ContainerReady => {
            container_id => "$container_id",
            allocations  => [ { allocation_id => $dcd_and_goh_fixture->dematic_allocation_row->id } ],
            prl          => 'dcd',
        }
    ) );
    # pretend that containers arrived
    $dcd_and_goh_fixture->dematic_allocation_row
        ->allocation_items->first
        ->integration_container_items->first
        ->integration_container->update({
            arrived_at => \'routed_at',
        });


    # GIH allocation come to GOH integration point
    $dcd_and_goh_fixture->goh_allocation_row->update({
        status_id => $ALLOCATION_STATUS__DELIVERING,
    });

    my $message_data = $self->deliver_response_payload(
        $dcd_and_goh_fixture->goh_allocation_row,
        { destination_id => $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION }
    );
    $dcd_and_goh_fixture->goh_allocation_row->mark_as_delivered(
        $message_data, $APPLICATION_OPERATOR_ID
    );

    return $self->schema
        ->resultset('Public::IntegrationContainer')
        ->get_active_container_row($container_id);
}

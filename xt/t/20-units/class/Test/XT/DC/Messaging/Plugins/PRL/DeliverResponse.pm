package Test::XT::DC::Messaging::Plugins::PRL::DeliverResponse;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};

use Test::XT::Data;
use Test::XTracker::Data;
use XT::DC::Messaging::Plugins::PRL::DeliverResponse;
use XTracker::Constants::FromDB qw/
    :allocation_item_status
    :allocation_status
    :prl_delivery_destination
    :shipment_item_status
    :storage_type
/;
use vars qw/ $PRL_DELIVERY_DESTINATION__GOH_DIRECT /;
use XTracker::Constants qw /:prl_type/;
use Test::XTracker::RunCondition prl_phase => 'prl';
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

=head1 NAME

Test::XT::DC::Messaging::Plugins::PRL::DeliverResponse

=head1 DESCRIPTION

Unit tests for XT::DC::Messaging::Plugins::PRL::DeliverResponse

=cut

sub test__basic_deliver_response_success : Tests() {
    my $self = shift;

    my $allocation = $self->create_delivering_allocation;

    note "send deliver_response";
    my $deliver_response_message = $self->create_deliver_response_message($allocation);
    lives_ok( sub { $self->send_message( $deliver_response_message ) },
        "deliver_response handler lived" );

    note "Check allocation status has been updated";
    $allocation->discard_changes;

    is ($allocation->status_id, $ALLOCATION_STATUS__DELIVERED,
        "Allocation status updated to delivered");
}

sub test__wrong_prl : Tests() {
    my $self = shift;

    my $allocation = $self->create_delivering_allocation;

    my $bad_prl = 'fake';

    note "send deliver_response with the wrong prl";
    my $deliver_response_message = $self->create_deliver_response_message(
        $allocation,
        prl => $bad_prl,
    );

    throws_ok(
        sub { $self->send_message( $deliver_response_message ) },
        qr/Couldn't find allocation matching id \[${\$allocation->id}\] for prl \[$bad_prl\]/,
        "deliver_response handler dies with missing allocation",
    );
}

sub test__missing_allocation : Tests {
    my $self = shift;

    my $highest_allocation_id = $self->{schema}->resultset('Public::Allocation')->get_column('id')->max() // 0;
    my $missing_allocation_id = $highest_allocation_id + 23;

    my $missing_allocation_message = $self->create_message(
        DeliverResponse => {
            allocation_id => $missing_allocation_id,
            success       => $PRL_TYPE__BOOLEAN__TRUE,
            reason        => '',
            prl           => 'dcd',
        }
    );

    throws_ok(
        sub { $self->send_message( $missing_allocation_message ) },
        qr/Couldn't find allocation matching id \[$missing_allocation_id\]/,
        "deliver_response handler dies with missing allocation",
    );

}

sub create_delivering_allocation {
    my ($self, $delivery_destination) = @_;

    $delivery_destination //= $PRL_DELIVERY_DESTINATION__GOH_DIRECT;

    # Create an order with two hanging items
    my $data = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );

    # Note: This might or might not create an allocation in a PRL
    # that does deliver+prepare depending on the current config,
    # but since we're updating statuses manually and faking the
    # deliver_response message, it doesn't actually matter for
    # this test if the allocation is in the wrong kind of PRL.
    my @goh_pids = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__HANGING,
        how_many => 2
    });
    my $shipment = $data->new_order( products => \@goh_pids )
        ->{'shipment_object'};

    is ($shipment->allocations->count, 1, "Shipment has 1 allocation");
    my $allocation = $shipment->allocations->first;

    # Pretend the PRL has picked everything and XT has requested the
    # allocation goes to the direct lane and sent the deliver message.
    $shipment->shipment_items->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED
    });
    $allocation->allocation_items->update({
        status_id => $ALLOCATION_ITEM_STATUS__PICKED
    });
    $allocation->update({
        status_id        => $ALLOCATION_STATUS__DELIVERING,
        prl_delivery_destination_id => $delivery_destination,
    });

    return $allocation;
}

sub create_deliver_response_message {
    my ($self, $allocation, %overrides) = @_;

    # Build a set of allocation item details for the deliver_response message
    my @item_details = map {
        {
            sku          => $_->variant->sku,
            delivered_at => $self->schema->db_now()->strftime('%FT%T%z'),
            destination  => $allocation->prl_delivery_destination->message_name,
        }
    } $allocation->shipment->shipment_items;

    # Setup a deliver_response message
    my $deliver_response_message = $self->create_message(
        DeliverResponse => {
            allocation_id => $allocation->id,
            item_details  => \@item_details,
            success       => $PRL_TYPE__BOOLEAN__TRUE,
            reason        => '',
            prl           => $allocation->prl->amq_identifier,
            %overrides,
        }
    );

    return $deliver_response_message;
}

1;

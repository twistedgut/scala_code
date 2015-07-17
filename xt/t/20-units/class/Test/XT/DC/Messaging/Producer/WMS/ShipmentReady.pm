package Test::XT::DC::Messaging::Producer::WMS::ShipmentReady;
use NAP::policy "tt", 'class', 'test';

BEGIN {
    extends 'NAP::Test::Class';
};

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::MockObject;
use Test::XT::Data::Container;

sub test__transform :Tests {
    my ($self) = @_;

    my $message_queue = Test::XTracker::MessageQueue->new();

    my ($shipment, $expected_client_code) = $self->_create_mock_shipment();

    my ($headers, $body) = $message_queue->transform('XT::DC::Messaging::Producer::WMS::ShipmentReady',
        $shipment);
    note('Generated data for "shipment_received" message');
    is($body->{containers}->[0]->{items}->[0]->{client}, $expected_client_code, 'Correct client code');
}

sub _create_mock_shipment {
    my ($self) = @_;

    my @containers = Test::XT::Data::Container->get_unique_ids();

    my ($channel, $product_data) = Test::XTracker::Data->grab_products({
        how_many => 1,
    });
    my $shipment = Test::XTracker::Data->create_shipment();
    my $shipment_item = Test::XTracker::Data->create_shipment_item({
        shipment_id     => $shipment->id(),
        variant_id      => $product_data->[0]->{variant_id},
    });

    my $mock_shipment = Test::MockObject->new();
    $mock_shipment->set_isa('XTracker::Schema::Result::Public::Shipment');
    $mock_shipment->mock('is_pick_complete', sub { 1 });
    $mock_shipment->mock('id', sub { $shipment->id() });
    $mock_shipment->mock('get_picked_items_by_container', sub { return { $containers[0] => [$shipment_item] } });

    return ($mock_shipment, $channel->client()->get_client_code());
}

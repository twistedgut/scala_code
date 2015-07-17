package Test::XT::DC::Messaging::Producer::WMS::ShipmentReject;
use NAP::policy "tt", 'class', 'test';

BEGIN {
    extends 'NAP::Test::Class';
};

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::XT::Data::Container;

use XTracker::Constants::FromDB qw(
    :shipment_item_status
);

sub test__transform :Tests {
    my ($self) = @_;

    my $message_queue = Test::XTracker::MessageQueue->new();

    my ($shipment, $expected_client_code) = $self->_create_shipment();

    my ($headers, $body) = $message_queue->transform('XT::DC::Messaging::Producer::WMS::ShipmentReject',{
        shipment_id => $shipment->id(),
    });
    note('Generated data for "shipment_reject" message');
    is($body->{containers}->[0]->{items}->[0]->{client}, $expected_client_code, 'Correct client code');
}

sub _create_shipment {
    my ($self) = @_;

    my ($channel, $pids) = Test::XTracker::Data->grab_products({ how_many => 1 });
    my @container_ids = Test::XT::Data::Container->create_new_containers({ how_many => 1 });

    my $shipment = Test::XTracker::Data->create_domestic_order(
        channel => $channel,
        pids    => $pids,
    )->shipments()->first();

    $shipment->shipment_items->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED,
        container_id            => $container_ids[0],
    });

    return ($shipment, $channel->client()->get_client_code());
}

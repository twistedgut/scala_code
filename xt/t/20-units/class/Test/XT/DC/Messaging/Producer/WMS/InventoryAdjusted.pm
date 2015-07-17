package Test::XT::DC::Messaging::Producer::WMS::InventoryAdjusted;
use NAP::policy "tt", 'class', 'test';

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::XT::Data::Quantity';
};

use Test::XTracker::MessageQueue;
use Test::XTracker::Data;

sub test__transform :Tests {
    my ($self) = @_;

    my $message_queue = Test::XTracker::MessageQueue->new();

    my ($channel, $product_data) = Test::XTracker::Data->grab_products({
        how_many => 1,
    });
    my $quantity = $self->data__quantity__insert_quantity({
        variant_id  => $product_data->[0]->{variant_id},
        location_id => Test::XTracker::Data->get_main_stock_location()->id(),
        channel     => $channel,
    });
    my $expected_client_code = $channel->client()->get_client_code();

    my ($headers, $body) = $message_queue->transform('XT::DC::Messaging::Producer::WMS::InventoryAdjusted',
        $quantity);
    note('Generated data for "inventory_adjusted" message');
    is($body->{client}, $expected_client_code, "Correct client code: $expected_client_code");
}

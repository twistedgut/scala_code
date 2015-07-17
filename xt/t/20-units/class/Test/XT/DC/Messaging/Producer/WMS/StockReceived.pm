package Test::XT::DC::Messaging::Producer::WMS::StockReceived;
use NAP::policy "tt", 'class', 'test';

BEGIN {
    extends 'NAP::Test::Class';
};

use Test::XT::Data::PutawayPrep;
use XTracker::Database::PutawayPrep;
use Test::XTracker::MessageQueue;

sub test__transform :Tests {
    my ($self) = @_;

    my $message_queue = Test::XTracker::MessageQueue->new();
    my $test_data = Test::XT::Data::PutawayPrep->new();

    my ($stock_process, $product_data) = $test_data->create_product_and_stock_process(1, {
        voucher    => 0,
        return     => 0,
        group_type => XTracker::Database::PutawayPrep->name(),
    });
    my $expected_client_code = $stock_process->channel()->client()->get_client_code();

    my ($headers, $body) = $message_queue->transform('XT::DC::Messaging::Producer::WMS::StockReceived', {
        sp => $stock_process,
    });
    note('Generated data for "stock_receive" message');
    is($body->{items}->[0]->{client}, $expected_client_code, 'Correct client code');
}

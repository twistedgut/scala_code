package Test::XTracker::Schema::Result::Public::Delivery;
use NAP::policy "tt", qw/test class/;

use Test::XTracker::Data;

BEGIN {
    extends 'NAP::Test::Class';
};

sub test__cancel_delivery :Tests {
    my ($self) = @_;

    my $delivery_rs = $self->schema()->resultset('Public::Delivery');

    my $delivery = $self->_create_putaway_delivery_with_stock_process();

    lives_ok {
        $delivery->cancel_delivery(Test::XTracker::Data->get_application_operator_id());
    } 'cancel_delivery lives()';

    ok($delivery->cancel(), 'Delivery is marked as cancelled');
}

sub _create_putaway_delivery_with_stock_process {
    my ($self) = @_;

    my ($channel, $product_data) = Test::XTracker::Data->grab_products({
        how_many=>1,
    });
    $product_data = $product_data->[0]; # Just need the first entry

    my $product = $product_data->{product};

    my $purchase_order = Test::XTracker::Data->setup_purchase_order($product->id);

    my ($delivery) = Test::XTracker::Data->create_delivery_for_po(
        $purchase_order->id,
        "putaway",
    );

    my ($stock_process_row) = Test::XTracker::Data->create_stock_process_for_delivery(
        $delivery,
    );

    $stock_process_row->create_related('rtv_stock_process', {
        originating_uri_path        => '',
        originating_sub_section_id  => 1,
    });

    $stock_process_row->create_related('log_putaway_discrepancies', {
        variant_id  => $product_data->{variant_id},
        channel_id  => $channel->id(),
    });

    return $delivery;
}

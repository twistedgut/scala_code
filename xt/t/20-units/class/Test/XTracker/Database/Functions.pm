package Test::XTracker::Database::Functions;

use NAP::policy "tt", 'test';

use parent "NAP::Test::Class";

use XTracker::Constants::FromDB ':shipment_item_status';

use Test::XTracker::Data;

sub startup : Test(startup) {
    my ( $self ) = @_;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
}

sub test_canc_adj_quantity_trigger : Tests {
    my ( $self ) = @_;

    # Just make sure we have a variant with stock
    my $channel = $self->{channel} = Test::XTracker::Data->channel_for_nap;
    my $pid_hash = (Test::XTracker::Data->grab_products(
        { channel_id => $channel->id, force_create => 1, }
    ))[1][0];
    my $variant = $pid_hash->{variant};
    Test::XTracker::Data->ensure_stock( $pid_hash->{pid}, $pid_hash->{size_id}, $channel->id );

    # Create an order
    my ($order) = Test::XTracker::Data->create_db_order({
        pids => [$pid_hash],
        base => { channel_id => $channel->id, },
    });
    my $si = $order->shipments->related_resultset('shipment_items')->slice(0,0)->single;

    # Get the current count for cancel_pending items for the product
    my $schema = $self->{schema};
    my %args = (
        product_id => $variant->product_id,
        channel_id => $channel->id,
    );
    my ($pss) = grep { $_ } map {
        $_->find(\%args) || $_->create({%args, cancel_pending => 0})
    } $schema->resultset('Product::StockSummary');
    my $cp_count = $pss->cancel_pending;

    # Check count+1 when item goes to cancel pending
    $si->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING});
    is( $pss->discard_changes->cancel_pending, $cp_count + 1,
        'cancel pending count should have increased by one' );

    # Check count==count when item goes out of cancel pending
    $si->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED});
    is( $pss->discard_changes->cancel_pending, $cp_count,
        'cancel pending count should have decreased by one' );

    # Check count==count when item not going into or out of cancel pending
    $si->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED});
    is( $pss->discard_changes->cancel_pending, $cp_count,
        'not going through cancel pending count should have stay the same' );
}

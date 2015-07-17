package Test::XT::DC::Messaging::Plugins::PRL::ItemPicked;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "NAP::Test::Class::PRLMQ";
};
use Test::XTracker::RunCondition prl_phase => 'prl';
use XT::DC::Messaging::Plugins::PRL::ItemPicked;

use Test::XT::Data;
use Test::XTracker::Data;
use XTracker::Constants::FromDB qw/
    :allocation_status :allocation_item_status :storage_type :shipment_item_status /;
use Test::XT::Data::Container;
use Test::XTracker::Data::Operator;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

=head1 NAME

Test::XT::DC::Messaging::Plugins::PRL::ItemPicked

=head1 DESCRIPTION

Unit tests for XT::DC::Messaging::Plugins::PRL::ItemPicked

=cut

sub item_picked_messages : Tests() {
    my $self = shift;

    my $user = "金牌口水雞";
    my $container_id = Test::XT::Data::Container->get_unique_id();

    # Create an order with three items of the same SKU
    my ($pid) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many => 1,
    });
    my $shipment = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    )->new_order(
        products  => [($pid) x 3],
        no_ensure => 1,
        dont_allocate => 1,
    )->{'shipment_object'};

    my ($si_cancelled, @si_regular) = $shipment->shipment_items;
    my $sku = $si_cancelled->variant->sku;

    # Allocate the shipment, to create the initial allocation items
    my ($allocation) = $shipment->allocate({
        operator_id => $APPLICATION_OPERATOR_ID
    });
    my $ai_cancelled = $si_cancelled->active_allocation_item;
    my @ai_regular = map { $_->active_allocation_item } @si_regular;

    # Cancel one item
    $si_cancelled->update({
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING });

    # Allocate the shipment, which should update the allocation items
    $shipment->allocate({
        operator_id => $APPLICATION_OPERATOR_ID
    });

    # Set the AI's that are Requested to Picking
    $_->update({ status_id => $ALLOCATION_ITEM_STATUS__PICKING }) for
        $allocation->allocation_items->search({
            status_id => $ALLOCATION_ITEM_STATUS__REQUESTED
        });

    note("Shipment created and allocated, with one cancelled item, and two picking");

    # Setup the ItemPicked template
    my $template = $self->message_template(
        ItemPicked => {
            allocation_id => $allocation->id,
            client => $si_cancelled->variant->prl_client,
            pgid => 'p12345',
        }
    );
    my $item_picked = $template->({
        user => $user,
        sku => $sku,
        container_id => $container_id,
    });

    # After one item picked, the si_cancelled's AI should be unchanged, but we
    # should have flipped one of the other AI's to picked. After a second, they
    # should both be flipped.
    for ([ 1 => 'initial' ], [ 2 => 'second' ] ) {
        my ( $ai_in_status_picked, $message_ordinal ) = @$_;
        note("Sending $message_ordinal ItemPicked message");
        lives_ok( sub { $self->send_message( $item_picked ) },
            "ItemPicked handler lived" );

        my @picked_ais = grep {
            $_->discard_changes->status_id eq $ALLOCATION_ITEM_STATUS__PICKED
        } @ai_regular;
        is( (scalar @picked_ais), $ai_in_status_picked,
            "$ai_in_status_picked item(s) marked as picked");

        is( $ai_cancelled->discard_changes->status_id,
            $ALLOCATION_ITEM_STATUS__CANCELLED,
            "Cancelled AI still cancelled");
    }

    # A third item-picked should cause a fatal error
    throws_ok( sub { $self->send_message( $item_picked ) },
        qr/Can't find an Allocation Item with SKU \[$sku\] in status Picking/,
        "Third ItemPicked for non-existant item causes error" );

    # Check that the picked_* data in the AIs is as we'd hope
    for my $ai ( @ai_regular ) {
        my $ai_user = $ai->picked_by;
        utf8::decode( $ai_user );
        is( $ai_user, $user, "User matches for AI" );
        is( $ai->picked_into, $container_id, "Container ID matches for AI" );
    }
}

sub log_picking_user : Tests() {
    my $self = shift;

    my $operator = Test::XTracker::Data::Operator->create_new_operator();
    my $username = $operator->username;
    note "Created test operator: $username";

    my $container_id = Test::XT::Data::Container->get_unique_id();

    # Create an order with a test item of the same SKU, let it
    # be allocated.
    my ($pid) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many => 1,
    });
    my $shipment = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    )->new_order(
        products  => [$pid],
        no_ensure => 1,
    )->{'shipment_object'};

    my ($shipment_item) = $shipment->shipment_items;
    my $sku = $shipment_item->variant->sku;
    my $allocation_item = $shipment_item->active_allocation_item;
    my $allocation = $allocation_item->allocation;

    # Set the allocation and allocation_item to Picking
    $allocation_item->update({ status_id => $ALLOCATION_ITEM_STATUS__PICKING });
    $allocation->update({ status_id => $ALLOCATION_STATUS__PICKING });

    note("Shipment ".$shipment->id." created and allocated, item being picked");

    # Setup the ItemPicked template
    my $template = $self->message_template(
        ItemPicked => {
            allocation_id => $allocation->id,
            client => $shipment_item->variant->prl_client,
            pgid => 'p12345',
        }
    );
    my $item_picked = $template->({
        user => $operator->username,
        sku => $sku,
        container_id => $container_id,
    });

    lives_ok( sub { $self->send_message( $item_picked ) },
        "ItemPicked handler lived" );

    $allocation_item->discard_changes;

    is( $allocation_item->status_id, $ALLOCATION_ITEM_STATUS__PICKED,
        "allocation item marked as picked");
    is( $allocation_item->picked_by, $username,
        "picked_by username it correct" );

    my $ai_log_rs = $allocation_item->allocation_item_logs->search({
    },{
        'order_by' => {'-desc' => 'date'},
    });
    my $latest_entry = $ai_log_rs->first;
    ok ($latest_entry, "allocation_item_log entry created");

    is ($latest_entry->allocation_item_status_id, $ALLOCATION_ITEM_STATUS__PICKED,
        "Log shows allocation_item as picked");
    is ($latest_entry->operator_id, $operator->id,
        "Log shows correct operator id");

}

sub multiple_of_same_sku :Test() {
    my $self = shift;

    my $container_id = Test::XT::Data::Container->get_unique_id();

    # Create an order with five items of the same SKU
    my ($pid) = Test::XTracker::Data->create_test_products({
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        how_many => 1,
    });

    my $shipment = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    )->new_order(
        products  => [($pid) x 5],
        no_ensure => 1,
    )->{'shipment_object'};

    $shipment->allocations->first->allocation_items->update({
        status_id => $ALLOCATION_ITEM_STATUS__PICKING
    });

    # Setup the ItemPicked template
    my $template = $self->message_template(
        ItemPicked => {
            allocation_id => $shipment->allocations->first->id,
            client => 'NAP',
            pgid => 'p12345',
            user => 'p.taylor',
            sku => $shipment->shipment_items->first->variant->sku,
            container_id => $container_id,
        }
    );

    foreach (1..5) {
        my $new_dupe_msg = $template->({});
        $self->send_message($new_dupe_msg);
    }

    # ok messages sent.
    # 5 items with the same sku should have been picked. now check they are:

    $shipment->discard_changes;
    my $items_picked = 0;

    foreach my $ai ($shipment->allocations->first->allocation_items->all) {
        $ai->discard_changes;
        $items_picked++ if ($ai->status_id == $ALLOCATION_ITEM_STATUS__PICKED);
    }

    is($items_picked, 5, 'All Items picked');

}

#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

item_count.t - Test the Item Count screen

=head1 DESCRIPTION

Test the Item Count screen.

#TAGS goodsin itemcount xpath printer needsrefactor voucher fulcrum http whm

=cut

use FindBin::libs;

use Test::NAP::Messaging::Helpers qw(atleast);
use Test::XTracker::Data;
use Test::XTracker::Mechanize::GoodsIn;
use Test::XTracker::MessageQueue;
use XTracker::Config::Local 'config_var';

use XTracker::Constants::FromDB qw(
    :delivery_item_status
    :delivery_status
    :stock_process_status
    :stock_order_status
    :purchase_order_status
);

# create an amq test object and clear the queue
my ($amq,$app) = Test::XTracker::MessageQueue->new_with_app;
my $broadcast_topic_name = config_var('Producer::Stock::DetailedLevelChange','destination');

# Test product
my $mech = Test::XTracker::Mechanize::GoodsIn->new();
my $flow = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::PrintStation',
    ],
    mech => $mech,
);
my $schema = Test::XTracker::Data->get_schema;

my $sender = Test::XTracker::MessageQueue->new();
# TODO: We should check a PO with a PID with multiple SKUs where one delivery
#       fully delivers one SKU. This was manually tested.

my $username = 'it.god';

Test::XTracker::Data->grant_permissions( $username, 'Goods In', 'Stock In', 3 );
Test::XTracker::Data->grant_permissions( $username, 'Goods In', 'Item Count', 3 );
Test::XTracker::Data->grant_permissions( $username, 'Goods In', 'Stock In', 3 );

{
    note "Test item count printer stations";
    $mech->login_as_department('Distribution');

    # Make sure operator doesn't have a printer station assigned
    $schema->resultset('Public::Operator')
           ->search({ username => $username })
           ->related_resultset('operator_preference')
           ->update({ printer_station_name => undef });

    # Select printer station for operator
    $flow->flow_mech__goodsin__itemcount
        ->assert_location( qr{^/My/SelectPrinterStation\?} );
    my @printers = map {
        $_->content_list
    } $mech->find_xpath( q{//select[@name='ps_name']/option} )->get_nodelist;
    # Remove the '-----' option - it's weird we even have this as the user
    # needs to pick a printer to advance
    shift @printers;
    ok( @printers, 'user can pick at least one item count printer' );

    my $test_printer = sub {
        my ( $expected_printer ) = @_;
        $flow->flow_mech__select_printer_station_submit($expected_printer)
            ->assert_location( '/GoodsIn/ItemCount' );
        $mech->has_feedback_success_ok(qr{Printer Station Selected});
        is( ($mech->find_xpath(q{//div[@class='station_name']/span})
                  ->pop
                  ->content_list)[0],
            $expected_printer,
            'displayed printer matches selected one'
        );
    };

    $test_printer->( $printers[0] );
    $mech->follow_link_ok({ text => 'Set Item Count Station' });
    $test_printer->( $printers[-1] );
}

{
    note "Testing a product delivery";
    my $stock_order = prepare_item_count();
    my $delivery = $stock_order->deliveries->next or die "Could not get delivery from stock order";
    my $delivery_item = $delivery->delivery_items->next;

    $mech->login_as_department('Distribution');

    ## restricted access
    ok( !$mech->ps_visible_on_item_count(),
        'Distribution cannot see Packing slip' );
    ok( !$mech->counts_visible_on_view_delivery($delivery->id),
        'Distribution cannot see item counts viewing delivery' );

    # If you are not in the distribution department the item count *must* match the
    # value entered in the packing slip. Not sure why, but that is the desired behaviour.
    my $submit_count = $delivery_item->packing_slip - 3;
    ok( $mech->submit_item_count_quantity_fails_ok( $submit_count ),
        "Distribution cannot submit mismatched item counts"    );

    ## unrestricted access
    foreach my $department ('Distribution Management', 'Stock Control') {
        $stock_order = prepare_item_count();
        $delivery = $stock_order->deliveries->next;
        $delivery_item = $delivery->delivery_items->next;

        $mech->login_as_department($department);

        ok( $mech->ps_visible_on_item_count(),
            "$department can see Packing slip" );
        ok( $mech->counts_visible_on_view_delivery($delivery->id),
            "$department can see item counts viewing delivery");
        ok( $mech->submit_item_count( $submit_count ),
            "$department can submit mismatched item counts" );
    }

    # Check values updated correctly for delivery item
    $delivery_item->discard_changes;
    is( $delivery_item->quantity, $submit_count, 'delivery item quantity correct' );

    # Check status_ids updated
    check_statuses_ok( $delivery_item, 'counted', $submit_count );

    # Now we need to finish the delivery.
    {
      my $count = $delivery_item->packing_slip - $submit_count;
      do_stock_in( $stock_order->stock_order_items->single, $count );

      my $delivery = $stock_order->deliveries->search({status_id => $DELIVERY_STATUS__NEW})->next;
      $mech->get_ok("/GoodsIn/ItemCount?delivery_id=" . $delivery->id, "Item count page to finish the delivery");

      # clear the queue
      $amq->clear_destination( $broadcast_topic_name );

      $mech->submit_item_count_ok( $count );

      # check stock update message sent
      my $variant = $stock_order->stock_order_items->first->variant;

      $amq->assert_messages({
        destination => $broadcast_topic_name,
        assert_header => superhashof({
            type => 'DetailedStockLevelChange',
        }),
        assert_body => superhashof({
            product_id => $variant->product_id,
            variants => superbagof({
                variant_id => $variant->id,
                levels => superhashof({
                    delivered_quantity => atleast(1),
                }),
            }),
        }),
      }, 'Broadcast Stock update sent via AMQ' );
    }
    check_statuses_ok( $delivery_item, 'counted', 10 );
}

{
    note "Testing a voucher delivery";
    # Test voucher
    my $voucher = Test::XTracker::Data->create_voucher;

    my $submit_count = 7;
    my $stock_order = prepare_item_count($voucher->id, $submit_count);
    my $delivery = $stock_order->deliveries->slice(0,0)->single;
    my $delivery_item = $delivery->delivery_items->slice(0,0)->single;

    $mech->get_ok('/GoodsIn/ItemCount?delivery_id='.$delivery->id);

    $mech->submit_item_count_ok( $submit_count );

    $delivery_item->discard_changes;
    is( $delivery_item->quantity, $submit_count, 'delivery item quantity correct' );

    # Check status ids updated
    check_statuses_ok( $delivery_item, 'counted', $submit_count );

    # Now we need to finish the delivery.
    {
      my $count = $stock_order->stock_order_items->first->quantity - $submit_count;
      do_stock_in( $stock_order->stock_order_items->single, $count );
      $sender->clear_destination('/queue/fulcrum/purchase_order');

      my $delivery = $stock_order->deliveries->search({status_id => $DELIVERY_STATUS__NEW})->slice(0,0)->single;
      $mech->get_ok("/GoodsIn/ItemCount?delivery_id=" . $delivery->id, "Item count page to finish the delivery");
      $mech->submit_item_count_ok( $count );
    }
    $sender->assert_messages({
        destination => '/queue/fulcrum/purchase_order',
    });
    check_statuses_ok( $delivery_item, 'counted', 10 );
}

done_testing;

# TODO: This needs to check setting statuses to various different values
# TODO: Generalise this sub so it can be used across different parts of the
#       goods in process
sub check_statuses_ok {
    my ( $delivery_item, $state, $count ) = @_;

    my %state_map = (
        counted => {
            delivery_item_status => $DELIVERY_ITEM_STATUS__COUNTED,
            delivery_status      => $DELIVERY_STATUS__COUNTED,
            stock_process_status => $STOCK_PROCESS_STATUS__NEW,
        },
    );

    my $stock_process_rs = $delivery_item->stock_processes;

    my $stock_process_group_id = $stock_process_rs->next->group_id;
    is( $_, $stock_process_group_id, 'group_id matches' )
        for $stock_process_rs->get_column('group_id')->all;

    is( $delivery_item->status_id, $state_map{$state}{delivery_item_status},
        'delivery item status set' );

    my $stock_order_item = $delivery_item->stock_order_item;
    is( $stock_order_item->status_id, $stock_order_item->check_status,
        'stock order item status set' );

    my $part = $count < $stock_order_item->quantity;

    my $delivery = $delivery_item->delivery;
    is( $delivery->status_id, $state_map{$state}{delivery_status},
        'delivery status set' );

    my $stock_order = $delivery->stock_order->discard_changes;;
    is( $stock_order->status_id,
        $part ? $STOCK_ORDER_STATUS__PART_DELIVERED
              : $STOCK_ORDER_STATUS__DELIVERED,
        'stock order status set' );

    my $purchase_order = $stock_order->purchase_order;
    is( $purchase_order->status_id,
        $part ? $PURCHASE_ORDER_STATUS__PART_DELIVERED
              : $PURCHASE_ORDER_STATUS__DELIVERED,
        'purchase order status set' );
    return;
}

=head2 prepare_item_count

Pass an $id to set up the PO for the item count stage. Will only copy with one
size pids and POs with one product.

Patches welcome ;)

=cut

sub prepare_item_count {
    my ($id,$count) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    if (!$id) {
        my (undef,$pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
            dont_ensure_stock => 1,
        });
        $id = $pids->[0]->{pid};
    }

    my $po = Test::XTracker::Data->setup_purchase_order([ $id ], {confirmed => 1});

    my $stock_order = $po->stock_orders->first;
    isa_ok( $stock_order, 'XTracker::Schema::Result::Public::StockOrder', 'prepare item count stock order' );

    $mech->login_as_department('Distribution');

    do_stock_in( $stock_order->stock_order_items->single, $count );

    return $stock_order;
}

sub do_stock_in {
    my ( $stock_order_item, $count) = @_;

    $flow->task__set_printer_station(qw/GoodsIn StockIn/);
    $flow->flow_mech__goodsin__stockin_packingslip($stock_order_item->stock_order_id)
        ->flow_mech__goodsin__stockin_packingslip__submit({
            $stock_order_item->variant->sku => $count//$stock_order_item->quantity,
        });
    # Every time we do a stock in we 'break' the following item count as we
    # don't have an item count printer selected. I realise this isn't the best
    # place for setting the printer but at least by putting it here we just do
    # it once
    $flow->task__set_printer_station(qw/GoodsIn ItemCount/);

}

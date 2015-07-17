#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use FindBin::libs;

use utf8;

use XTracker::Constants::FromDB     qw( :shipment_item_status :return_item_status :return_type
                                        :delivery_status :delivery_type
                                        :delivery_item_status :delivery_item_type
                                        :stock_process_type :stock_process_status );


use Test::XTracker::Data;
use Test::XTracker::Mechanize;


=head1 EN-1529: Convert From Exchange to Refund resets Return Item and Shipment Item Statuses

This test is to check that when an Exchange is Converted to a Return that the new Return Item created
has the same Status that the Exchange had before it got Cancelled and also that the original Shipment Item's
Status remains un-changed.

The problem before was that they were both being set to the Starting Statused which caused problems as the
Physical item that had been returned has remained in the same state either 'Passed QC' or 'Putaway', so it
had to be done again which in some cases led to Stock Problems.

=cut


my $schema  = Test::XTracker::Data->get_schema;
my $channel = Test::XTracker::Data->get_local_channel();
my @pids    = sort { $a->id <=> $b->id } map { $_->{product} } @{
    (Test::XTracker::Data->grab_products({
        channel => $channel,
        how_many => 2,
        how_many_variants => 2,
        ensure_stock_all_variants => 1,
    }))[1] };
my @pid1_vars   = $pids[0]->variants->search( {},{ order_by => 'me.id' } )->all;
my @pid2_vars   = $pids[1]->variants->search( {},{ order_by => 'me.id' } )->all;

# We need an rma to test with exchange instead of returns.
my $exchange_order = Test::XTracker::Data->create_db_order({
    #return_status_id => $RETURN_STATUS__PROCESSING,
    items => {
        $pid1_vars[1]->sku => { price => 250.00 },
        $pid2_vars[0]->sku => { price => 100.00 },
    }
});

Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Returns Pending', 2);
Test::XTracker::Data->set_department('it.god', 'Customer Care');

my $mech = Test::XTracker::Mechanize->new;
$mech->do_login;

$mech->order_nr($exchange_order->order_nr);

ok(my $shipment = $exchange_order->shipments->first, "Sanity check: the order has a shipment");

$mech->order_nr($exchange_order->order_nr);

my $return;
# create Exchange and test it created ok
$mech->test_create_rma( $shipment, 'exchange' )
     ->test_exchange_pending( $return = $shipment->returns->first );

$return->discard_changes;
$shipment->discard_changes;
my $ship_item   = $shipment->shipment_items->order_by_sku->first;
my $ret_item    = $return->return_items->not_cancelled->first;
my $exch_item   = $ret_item->exchange_shipment_item;

note "Shipment Item          ID: ".$ship_item->id.", SKU: ".$ship_item->get_sku;
note "Return Item            ID: ".$ret_item->id;
note "Exchange Shipment Item ID: ".$exch_item->id.", SKU: ".$exch_item->get_sku;

# check shipment/return item statuses
cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__RETURN_PENDING, "Shipment Item Status is 'Return Pending'" );
cmp_ok( $ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__AWAITING_RETURN, "Exchnage Return Item Status is 'Awaiting Return'" );
cmp_ok( $exch_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__NEW, "Exchange Shipment Item Status is 'New'" );

# now manually move some statuses along and they should still
# be the same when the exchange is converted to being a return
note "Setting Shipment Item Status to be 'Return Received'";
$ship_item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED } );
note "Setting Return Item Status to be 'Booked In'";
$ret_item->update( { return_item_status_id => $RETURN_ITEM_STATUS__BOOKED_IN } );

# Also create Delivery/Delivery Item records and their links to the return
# so as to similuate the return having been Booked In
note "Creating Delivery records to simulate return being 'Booked In'";
my $delivery    = $schema->resultset('Public::Delivery')->create( {
                                            date        => \"now()",
                                            status_id   => $DELIVERY_STATUS__COUNTED,
                                            type_id     => $DELIVERY_TYPE__CUSTOMER_RETURN,
                                        } );
$delivery->create_related( 'link_delivery__return', { return_id => $return->id } );
my $deliv_item  = $delivery->delivery_items->create( {
                                            packing_slip    => 1,
                                            quantity        => 1,
                                            status_id       => $DELIVERY_ITEM_STATUS__COUNTED,
                                            type_id         => $DELIVERY_ITEM_TYPE__CUSTOMER_RETURN,
                                        } );
$deliv_item->create_related( 'link_delivery_item__return_item', { return_item_id => $ret_item->id } );
$deliv_item->stock_processes->create( {
                                quantity    => 1,
                                type_id     => $STOCK_PROCESS_TYPE__MAIN,
                                status_id   => $STOCK_PROCESS_STATUS__NEW,
                            } );

# now convert the Exchange
$mech->test_convert_from_exchange( $return );

# get the new values
foreach my $rec ( $shipment, $return, $ship_item, $ret_item, $exch_item, $delivery, $deliv_item ) {
    $rec->discard_changes
}
# get the new return item
my $new_ret_item    = $return->return_items->not_cancelled->first;

# check to make sure statuses are correct
cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED, "Shipment Item Status is STILL 'Return Received'" );
cmp_ok( $ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED, "Old Exchange Return Item Status is NOW 'Cancelled'" );
cmp_ok( $new_ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__BOOKED_IN, "New Return Item Status IS 'Booked In'" );
cmp_ok( $new_ret_item->return_type_id, '==', $RETURN_TYPE__RETURN, "New Return Item Type is 'Return'" );
cmp_ok( $exch_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED, "Exchange Shipment Item Status is NOW 'Cancelled'" );

# check to make sure the Delivery Item is now linked to the new Return Item and no longer the old one
cmp_ok( $deliv_item->get_return_item->id, '==', $new_ret_item->id, "Delivery Item NOW Linked to New Return Item" );
cmp_ok( $ret_item->link_delivery_item__return_items->count(), '==', 0, "Old Exchange Return Item has NO Delivery Item Links" );

done_testing;

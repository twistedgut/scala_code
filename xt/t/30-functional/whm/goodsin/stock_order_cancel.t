#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

stock_order_cancel.t - Cancel a Stock Order

=head1 DESCRIPTION

Test cancelling a Stock Order and a Stock Order Item, making sure the statuses
get updated properly, including for the Purchase Order.

Cancel all stock order items and cancel the stock order and un-cancel again.

Test changing the Ordered Quantity on a Stock Order Item when less has been
delivered than expected and making sure the statuses on the Stock Order Item,
Stock Order and Purchase Order are correct.

Test the 'check_stock_order_status' function that is in
XTracker::Database::PurchaseOrder. This is really a unit
test but makes sense to do it in this test as it all to
do with checking the statuses of Stock Orders.

#TAGS goodsin needswork duplication xpath purchaseorder whm

=cut

use FindBin::libs;


use Time::HiRes 'time';

use Test::XTracker::Data;
use Test::XTracker::Mechanize;

use DateTime::Format::Pg;
use XTracker::Constants qw/:application/;
use XTracker::Constants::FromDB qw(
    :currency
    :delivery_item_status
    :delivery_item_type
    :delivery_status
    :delivery_type
    :purchase_order_status
    :purchase_order_type
    :season
    :shipment_window_type
    :stock_order_item_status
    :stock_order_item_type
    :stock_order_status
    :stock_order_type
);
use XTracker::Database::PurchaseOrder   qw( check_stock_order_status );

my $mech    = Test::XTracker::Mechanize->new;
my $schema  = Test::XTracker::Data->get_schema;
my $channel = Test::XTracker::Data->get_local_channel();

Test::XTracker::Data->grant_permissions( 'it.god', 'Stock Control', 'Purchase Order', 3 );

# set-up purchase order
my $purch_order = _create_dummy_po( $schema, $channel, 2, 2 );
isa_ok( $purch_order, 'XTracker::Schema::Result::Public::PurchaseOrder' );

$mech->do_login;

test_cancel_stock_order( $mech, $channel, $purch_order, 1 );
test_change_soi_ordered_qty( $mech, $channel, 1 );
test_check_stock_order_status( $channel, 1 );

done_testing;

# This tests cancelling a Stock Order and a Stock Order Item and making sure
# the statuses get updated properly including for the Purchase Order
sub test_cancel_stock_order {
    my ( $mech, $channel, $purch_order, $oktodo )   = @_;

    my $tmp;
    my @tmp;
    my @soi;
    my $pc;

    SKIP: {
        skip "test_cancel_stock_order",1        if ( !$oktodo );

        note "TESTING test_cancel_stock_order";

        my $stock_ord_rs= $schema->resultset('Public::StockOrder')->search( { 'me.purchase_order_id' => $purch_order->id }, { order_by => 'me.id' } );
        my @stock_ords  = $stock_ord_rs->all;
        my $po_link     = '/StockControl/PurchaseOrder/Overview?po_id='.$purch_order->id;

        # get to the PO Overview page via searching for the PO Number
        my $po_num  = $purch_order->purchase_order_number;
        $mech->get_ok( '/StockControl/PurchaseOrder' );
        $mech->submit_form_ok( {
            form_name => "searchForm",
            with_fields => {
                            purchase_order_number => $po_num,
                        },
            button      => 'submit',
        }, 'PO Search' );
        $mech->no_feedback_error_ok;
        $mech->follow_link_ok({ text_regex => qr/$po_num/ }, "PO Overview");

        # update all stock order items for the first product
        # to cancel to test product channel cancel flag
        $tmp    = $schema->resultset('Public::StockOrder')->search(
                                                    {
                                                        'me.product_id'     => $stock_ords[0]->product_id,
                                                        'me.id'             => { '!='   => $stock_ords[0]->id },
                                                    } );
        if ( defined $tmp ) {
            $tmp->update( { cancel => 1 } );
        }
        $pc     = $stock_ords[0]->product->product_channel->search( { channel_id => $channel->id } )->first;
        $pc->update( { cancelled => 0 } );

        # set-up the data for the next tests
        # set the last stock order as delivered

        # If Purchase Order is editable in XT then continue with cancellation process
        if ( $purch_order->is_editable_in_xt ) {
            note "Update Second Stock Order & Stock Order Item Records for Tests";
            $stock_ords[1]->update( { 'status_id' => $STOCK_ORDER_STATUS__DELIVERED } );
            @tmp    =  $stock_ords[1]->stock_order_items->search( {}, { order_by => 'me.id' } )->all;
            $tmp[0]->update( { 'status_id' => $STOCK_ORDER_ITEM_STATUS__DELIVERED } );      # first item delivered
            $tmp[1]->update( { 'cancel' => 1 } );                                           # second item cancelled
            _setup_delivery_for_so( $schema, $stock_ords[1], 1, 1 );        # set-up a delivery for first item


            #
            # cancel all stock order items and cancel the stock order & un-cancel again
            #

            # only cancel 1 first to make sure both are cancelled
            $tmp    = $stock_ords[0]->id;
            $mech->follow_link_ok( { url_regex => qr/so_id=$tmp/ }, 'SO: '.$stock_ords[0]->id );
            @soi    = $stock_ords[0]->stock_order_items->search( {}, { order_by => 'me.id' } )->all;
            $mech->submit_form_ok( {
                with_fields => {
                    'cancel-'.$soi[0]->id   => 'on',
                },
                button  => 'submit',
            }, 'Cancel 1/2 SO Items' );
            $mech->no_feedback_error_ok;
            $mech->has_feedback_success_ok( qr/Stock order updated successfully./ );
            $stock_ord_rs->reset;
            $pc->discard_changes;
            $purch_order->discard_changes;
            @stock_ords = $stock_ord_rs->all;
            cmp_ok( $stock_ords[0]->cancel, '==', 0, "SO Shouldn't be Cancelled Yet: ".$stock_ords[0]->id );
            @soi    = $stock_ords[0]->stock_order_items->search( {}, { order_by => 'me.id' } )->all;
            cmp_ok( $soi[0]->cancel, '==', 1, 'SO Item Cancelled: '.$soi[0]->id );
            cmp_ok( $soi[1]->cancel, '==', 0, 'SO Item NOT YET Cancelled: '.$soi[1]->id );
            cmp_ok( $pc->cancelled, '==', 0, 'Product Channel NOT YET Cancelled for '.$stock_ords[0]->product_id );
            cmp_ok( $purch_order->status_id, '==', $PURCHASE_ORDER_STATUS__PART_DELIVERED, 'Purchase Order Status set to Part Delivered' );

            # now cancel the 2nd and they both should now be cancelled
            $mech->submit_form_ok( {
                with_fields => {
                    'cancel-'.$soi[1]->id   => 'on',
                },
                button  => 'submit',
            }, 'Cancel 2/2 SO Items' );
            $mech->no_feedback_error_ok;
            $mech->has_feedback_success_ok( qr/Stock order updated successfully./ );
            # check the SO cancel flag & fields in form
            $stock_ord_rs->reset;
            $purch_order->discard_changes;
            @stock_ords = $stock_ord_rs->all;
            cmp_ok( $stock_ords[0]->cancel, '==', 1, 'Now Cancelled SO: '.$stock_ords[0]->id );
            $pc->discard_changes;
            @soi    = $stock_ords[0]->stock_order_items->search( {}, { order_by => 'me.id' } )->all;
            cmp_ok( $stock_ords[0]->cancel, '==', 1, 'Cancelled SO: '.$stock_ords[0]->id );
            map { cmp_ok( $_->cancel, '==', 1, 'SO Item Cancelled: '.$_->id ) } @soi;
            cmp_ok( $pc->cancelled, '==', 1, 'Product Channel Cancelled for '.$stock_ords[0]->product_id );
            $mech->form_with_fields('cancel-'.$soi[0]->id);
            is( $mech->value( 'cancel-'.$soi[0]->id ), 'on', 'Cancel On for SOI: '.$soi[0]->id );
            @tmp    = $mech->get_table_row( $soi[0]->variant->sku );
            like( $tmp[5], qr/Cancelled/, 'Cancel Status for SOI: '.$soi[0]->id );
            is( $mech->value( 'cancel-'.$soi[1]->id ), 'on', 'Cancel On for SOI: '.$soi[1]->id );
            @tmp    = $mech->get_table_row( $soi[1]->variant->sku );
            like( $tmp[5], qr/Cancelled/, 'Cancel Status for SOI: '.$soi[1]->id );
            cmp_ok( $purch_order->status_id, '==', $PURCHASE_ORDER_STATUS__DELIVERED, 'Purchase Order Status set to Delivered' );

            # now un-cancel the items
            $mech->submit_form_ok( {
                with_fields => {
                    'cancel-'.$soi[0]->id   => 'off',
                    'cancel-'.$soi[1]->id   => 'off',
                },
                button  => 'submit',
            }, 'Un-Cancel all SO Items' );
            $mech->no_feedback_error_ok;
            $stock_ord_rs->reset;
            $purch_order->discard_changes;
            @stock_ords = $stock_ord_rs->all;
            cmp_ok( $stock_ords[0]->cancel, '==', 0, 'Un-Cancelled SO: '.$stock_ords[0]->id );
            $pc->discard_changes;
            @soi    = $stock_ords[0]->stock_order_items->search( { }, { order_by => 'me.id' } )->all;
            cmp_ok( $stock_ords[0]->cancel, '==', 0, 'Un-Cancelled SO: '.$stock_ords[0]->id );
            map { cmp_ok( $_->cancel, '==', 0, 'SO Item Un-Cancelled: '.$_->id ) } @soi;
            cmp_ok( $pc->cancelled, '==', 0, 'Product Channel Un-Cancelled for '.$stock_ords[0]->product_id );
            $mech->form_with_fields('cancel-'.$soi[0]->id);
            is( $mech->value( 'cancel-'.$soi[0]->id ), 'off', 'Cancel Off for SOI: '.$soi[0]->id );
            @tmp    = $mech->get_table_row( $soi[0]->variant->sku );
            like( $tmp[5], qr/On Order/, 'On Order Status for SOI: '.$soi[0]->id );
            is( $mech->value( 'cancel-'.$soi[1]->id ), 'off', 'Cancel Off for SOI: '.$soi[1]->id );
            @tmp    = $mech->get_table_row( $soi[1]->variant->sku );
            like( $tmp[5], qr/On Order/, 'On Order Status for SOI: '.$soi[1]->id );
            cmp_ok( $purch_order->status_id, '==', $PURCHASE_ORDER_STATUS__PART_DELIVERED, 'Purchase Order Status set to Part Delivered' );


            #
            # cancel a stock order and all stock order items should be cancelled
            # and purchase order status should be changed to Delivered
            # and un-cancel stock order as well
            #

            $mech->get_ok( $po_link );
            $mech->submit_form_ok( {
                with_fields => {
                    'edit_cancel_'.$stock_ords[0]->id   => 'on',
                    'cancel_'.$stock_ords[0]->id        => 'on',
                },
                button  => 'submit',
            }, 'Cancel all of SO: '.$stock_ords[0]->id );
            $mech->no_feedback_error_ok;
            $stock_ords[0]->discard_changes;
            $stock_ords[1]->discard_changes;
            $pc->discard_changes;
            cmp_ok( $stock_ords[0]->cancel, '==', 1, 'Cancelled SO: '.$stock_ords[0]->id );
            @soi = $stock_ords[0]->stock_order_items->search( { }, { order_by => 'me.id' } )->all;
            map { cmp_ok( $_->cancel, '==', 1, 'SO Item also Cancelled: '.$_->id ) } @soi;
            cmp_ok( $pc->cancelled, '==', 1, 'Product Channel Cancelled for '.$stock_ords[0]->product_id );
            $tmp    = $mech->form_with_fields('cancel_'.$stock_ords[0]->id);
            is( $mech->value( 'cancel_'.$stock_ords[0]->id ), 'on', "Cancel field 'On' in form for SO: ".$stock_ords[0]->id );
            @tmp    = $mech->get_table_row_by_xpath(q{//table[@class='data']//tr[td/a[@href =~ 'so_id'] = '%s' ]/td},$stock_ords[0]->product_id);
            like( $tmp[9], qr/Cancelled/, "'Cancelled' Status in form for SO: ".$stock_ords[0]->id );
            $purch_order->discard_changes;
            cmp_ok( $purch_order->status_id, '==', $PURCHASE_ORDER_STATUS__DELIVERED, 'Purchase Order Status set to Delivered' );
            # check second stock order still is unchanged and still Delivered and items are Delivered and Cancelled
            @soi    = $stock_ords[1]->stock_order_items->search( { }, { order_by => 'me.id' } )->all;
            cmp_ok( $stock_ords[1]->status_id, '==', $STOCK_ORDER_STATUS__DELIVERED, "Second Stock Order is STILL 'Delivered'" );
            cmp_ok( $soi[0]->status_id, '==', $STOCK_ORDER_ITEM_STATUS__DELIVERED, "Second Stock Order, First Item is STILL 'Delivered'" );
            cmp_ok( $soi[1]->cancel, '==', 1, "Second Stock Order, Second Item is STILL 'Cancelled'" );

            # Check the Initial Purchase Order Summary page
            # to check the Cancelled Status is shown there
            $mech->get_ok( '/StockControl/PurchaseOrder', "Go Back to the PO Summary after Search Page" );
            $mech->submit_form_ok( {
                with_fields => {
                                purchase_order_number => $po_num,
                            },
                button      => 'submit',
            }, 'PO Search' );
            $mech->no_feedback_error_ok;
            @tmp    = $mech->get_table_row_by_xpath(q{//table[@class='data']//tr[td/a[@href =~ 'so_id'] = '%s' ]/td},$stock_ords[0]->product_id);
            like( $tmp[8], qr/Cancelled/, "'Cancelled' Status on PO Summary Page for SO: ".$stock_ords[0]->id );

            # now un-cancel it
            $mech->get_ok( $po_link );
            $mech->submit_form_ok( {
                with_fields => {
                    'edit_cancel_'.$stock_ords[0]->id   => 'off',
                    'cancel_'.$stock_ords[0]->id        => 'off',
                },
                button  => 'submit',
            }, 'Un-Cancel all of SO: '.$stock_ords[0]->id );
            $mech->no_feedback_error_ok;
            $stock_ords[0]->discard_changes;
            $stock_ords[1]->discard_changes;
            $pc->discard_changes;
            cmp_ok( $stock_ords[0]->cancel, '==', 0, 'Un-Cancelled SO: '.$stock_ords[0]->id );
            @soi = $stock_ords[0]->stock_order_items->search( { }, { order_by => 'me.id' } )->all;
            map { cmp_ok( $_->cancel, '==', 0, 'SO Item also Un-Cancelled: '.$_->id ) } @soi;
            cmp_ok( $pc->cancelled, '==', 0, 'Product Channel Un-Cancelled for '.$stock_ords[0]->product_id );
            $tmp    = $mech->form_with_fields('cancel_'.$stock_ords[0]->id);
            isnt( $mech->value( 'cancel_'.$stock_ords[0]->id ), 'on', "Cancel field 'Off' in form for SO: ".$stock_ords[0]->id );
            @tmp    = $mech->get_table_row_by_xpath(q{//table[@class='data']//tr[td/a[@href =~ 'so_id'] = '%s' ]/td},$stock_ords[0]->product_id);
            like( $tmp[9], qr/On Order/, "'On Order' Status in form for SO: ".$stock_ords[0]->id );
            $purch_order->discard_changes;
            cmp_ok( $purch_order->status_id, '==', $PURCHASE_ORDER_STATUS__PART_DELIVERED, 'Purchase Order Status set back to Part Delivered' );
            # check second stock order still is unchanged and still Delivered and items are Delivered and Cancelled
            @soi    = $stock_ords[1]->stock_order_items->search( { }, { order_by => 'me.id' } )->all;
            cmp_ok( $stock_ords[1]->status_id, '==', $STOCK_ORDER_STATUS__DELIVERED, "Second Stock Order is STILL 'Delivered'" );
            cmp_ok( $soi[0]->status_id, '==', $STOCK_ORDER_ITEM_STATUS__DELIVERED, "Second Stock Order, First Item is STILL 'Delivered'" );
            cmp_ok( $soi[1]->cancel, '==', 1, "Second Stock Order, Second Item is STILL 'Cancelled'" );

        }
    };

    return $mech;
}

# This tests changing the Ordered Quantity on a Stock Order Item
# when less has been delivered than expected and making sure the
# statuses on the Stock Order Item, Stock Order & Purchase Order
# are correct
sub test_change_soi_ordered_qty {
    my ( $mech, $channel, $oktodo )     = @_;

    my $tmp;
    my @tmp;
    my @soi;
    my $pc;

    SKIP: {
        skip "test_change_soi_ordered_qty",1        if ( !$oktodo );

        note "TESTING test_change_soi_ordered_qty";

        # set-up purchase order with 2 Stock Orders each with 3 Stock Order Items
        my $purch_order = _create_dummy_po( $schema, $channel, 2, 3 );
        isa_ok( $purch_order, 'XTracker::Schema::Result::Public::PurchaseOrder' );

        # Only do the following if the purchase order is editable in XT.
        if ( $purch_order->is_editable_in_xt ) {

            my $stock_ord_rs= $schema->resultset('Public::StockOrder')->search( { 'me.purchase_order_id' => $purch_order->id }, { order_by => 'me.id' } );
            my @stock_ords  = $stock_ord_rs->all;
            my $po_link     = '/StockControl/PurchaseOrder/Overview?po_id='.$purch_order->id;
            my $so_link     = '/StockControl/PurchaseOrder/StockOrder?so_id='.$stock_ords[1]->id;

            #
            # set-up data for tests
            #

            note "Update First Stock Order & Stock Order Item Records for Tests to be Delivered";
            $stock_ords[0]->update( { 'status_id' => $STOCK_ORDER_STATUS__DELIVERED } );
            $stock_ords[0]->stock_order_items->update( { status_id => $STOCK_ORDER_ITEM_STATUS__DELIVERED } );
            _setup_delivery_for_so( $schema, $stock_ords[0], 0, 1 );        # set-up a delivery for the items

            note "Update Second Stock Order to be Part Delivered: 1 Delivered, 1 Part Deliverd & 1 On Order";
            $stock_ords[1]->update( { 'status_id' => $STOCK_ORDER_STATUS__PART_DELIVERED } );
            @soi    = $stock_ords[1]->stock_order_items->search( { }, { order_by => 'me.id' } )->all;
            $soi[0]->update( { status_id => $STOCK_ORDER_ITEM_STATUS__DELIVERED } );
            _setup_delivery_for_so( $schema, $stock_ords[1], 2, 1 );        # set-up a delivery for the first 2 items
            # increase the ordered quantity to be one greater than delivered so we're now Part Delivered
            $soi[1]->update( { quantity => ( $soi[1]->quantity + 1 ), status_id => $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED } );

            note "Update the Purchase Order to be Part Delivered";
            $purch_order->update( { status_id => $PURCHASE_ORDER_STATUS__PART_DELIVERED } );

            #
            # now change the ordered quantity of the part delivered item to be
            # in-line with the delivered quantity and check for correct statuses
            #

            note "Test updating Ordered Quantity to be in-line with Delivered Quantity for Part Delivered Item";
            $mech->get_ok( $so_link );
            $mech->submit_form_ok( {
                with_fields => {
                    'ordered-'.$soi[1]->id  => ( $soi[1]->quantity - 1 ),
                },
                button  => 'submit',
            }, "Update Ordered Quantity for SOI: ".$soi[1]->id );
            $mech->no_feedback_error_ok;

            # refresh data
            $_->discard_changes     foreach ( ( $purch_order, @stock_ords, @soi ) );

            cmp_ok( $soi[1]->status_id, '==', $STOCK_ORDER_ITEM_STATUS__DELIVERED, "Stock Order Item Status is now 'Delivered'" );
            cmp_ok( $stock_ords[1]->status_id, '==', $STOCK_ORDER_STATUS__PART_DELIVERED, "Stock Order Status is now 'Part Delivered'" );
            cmp_ok( $purch_order->status_id, '==', $PURCHASE_ORDER_STATUS__PART_DELIVERED, "Purchase Order Status is now 'Part Delivered'" );
            cmp_ok( $stock_ords[0]->status_id, '==', $STOCK_ORDER_STATUS__DELIVERED, "First Stock Order Status is STILL 'Delivered'" );

            note "Cancel remaing On Order Stock Order Item so that Stock Order & Purchase Order should be Delivered";
            $mech->submit_form_ok( {
                with_fields => {
                    'cancel-'.$soi[2]->id   => 'on',
                },
                button  => 'submit',
            }, "Cancel SOI: ".$soi[2]->id );
            $mech->no_feedback_error_ok;

            # refresh data
            $_->discard_changes     foreach ( ( $purch_order, @stock_ords, @soi ) );

            cmp_ok( $soi[2]->cancel, '==', 1, "Stock Order Item's Cancel Flag is TRUE" );
            cmp_ok( $stock_ords[1]->status_id, '==', $STOCK_ORDER_STATUS__DELIVERED, "Stock Order Status is now 'Delivered'" );
            cmp_ok( $purch_order->status_id, '==', $PURCHASE_ORDER_STATUS__DELIVERED, "Purchase Order Status is now 'Delivered'" );
            cmp_ok( $stock_ords[0]->status_id, '==', $STOCK_ORDER_STATUS__DELIVERED, "First Stock Order Status is STILL 'Delivered'" );

        }
    };

    return $mech;
}

# This tests the 'check_stock_order_status' function that is in
# XTracker::Database::PurchaseOrder. This is really a unit test
# but makes sense to do it in this test as it all to do with
# checking the statuses of Stock Orders and I discovered the
# function wasn't correct as part of EN-2477
sub test_check_stock_order_status {
    my ( $channel, $oktodo )    = @_;

    my $dbh     = $schema->storage->dbh;
    my $tmp;
    my @soi;

    SKIP: {
        skip "test_check_stock_order_status",1      if ( !$oktodo );

        note "TESTING test_check_stock_order_status";

        # do all of this in a transaction so we can
        # roll-back without leaving data behind
        $schema->txn_do( sub {
            # set-up purchase order
            my $purch_order = _create_dummy_po( $schema, $channel, 1, 3 );
            isa_ok( $purch_order, 'XTracker::Schema::Result::Public::PurchaseOrder' );

            my $stock_order = $purch_order->stock_orders->first;
            note "Stock Order Id: ".$stock_order->id;
            note "Update All Stock Order Items to be 'On Order'";
            $stock_order->stock_order_items->update( { status_id => $STOCK_ORDER_ITEM_STATUS__ON_ORDER } );
            $tmp    = check_stock_order_status( $dbh, $stock_order->id );
            cmp_ok( $tmp, '==', $STOCK_ORDER_ITEM_STATUS__ON_ORDER, "Status returned is 'On Order'" );

            @soi    = $stock_order->stock_order_items->search( { }, { order_by => 'me.id' } )->all;

            note "Update 1 Item to be 'Part Delivered'";
            $soi[0]->discard_changes->update( { status_id => $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED } );
            $tmp    = check_stock_order_status( $dbh, $stock_order->id );
            cmp_ok( $tmp, '==', $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED, "Status returned is 'Part Delivered'" );

            note "Update another Item to be 'Delivered'";
            $soi[1]->discard_changes->update( { status_id => $STOCK_ORDER_ITEM_STATUS__DELIVERED } );
            $tmp    = check_stock_order_status( $dbh, $stock_order->id );
            cmp_ok( $tmp, '==', $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED, "Status returned is 'Part Delivered'" );

            note "Cancel the final Item";
            $soi[2]->discard_changes->update( { cancel => 1 } );
            $tmp    = check_stock_order_status( $dbh, $stock_order->id );
            cmp_ok( $tmp, '==', $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED, "Status returned is 'Part Delivered'" );

            note "Update Part Delivered Item to be 'Delivered'";
            $soi[0]->discard_changes->update( { status_id => $STOCK_ORDER_ITEM_STATUS__DELIVERED } );
            $tmp    = check_stock_order_status( $dbh, $stock_order->id );
            cmp_ok( $tmp, '==', $STOCK_ORDER_ITEM_STATUS__DELIVERED, "Status returned is 'Delivered'" );

            note "Un-Cancel the final Item";
            $soi[2]->discard_changes->update( { cancel => 0 } );
            $tmp    = check_stock_order_status( $dbh, $stock_order->id );
            cmp_ok( $tmp, '==', $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED, "Status returned is 'Part Delivered'" );

            note "Update All Items to be 'Part Delivered'";
            $stock_order->discard_changes->stock_order_items->update( { status_id => $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED } );
            $tmp    = check_stock_order_status( $dbh, $stock_order->id );
            cmp_ok( $tmp, '==', $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED, "Status returned is 'Part Delivered'" );

            note "Update All Items to be 'Delivered'";
            $stock_order->discard_changes->stock_order_items->update( { status_id => $STOCK_ORDER_ITEM_STATUS__DELIVERED } );
            $tmp    = check_stock_order_status( $dbh, $stock_order->id );
            cmp_ok( $tmp, '==', $STOCK_ORDER_ITEM_STATUS__DELIVERED, "Status returned is 'Delivered'" );

            note "Cancel All Items";
            $stock_order->discard_changes->stock_order_items->update( { cancel => 1 } );
            $tmp    = check_stock_order_status( $dbh, $stock_order->id );
            cmp_ok( $tmp, '==', $STOCK_ORDER_ITEM_STATUS__ON_ORDER, "Status returned is 'On Order'" );

            note "Un-Cancel 1 Item whose Status is 'Delivered'";
            $soi[1]->discard_changes->update( { cancel => 0 } );
            $tmp    = check_stock_order_status( $dbh, $stock_order->id );
            cmp_ok( $tmp, '==', $STOCK_ORDER_ITEM_STATUS__DELIVERED, "Status returned is 'Delivered'" );

            $schema->txn_rollback();
        } );
    };

    return;
}

#---------------------------------------------------------------

# creates a Purchase Order with Stock Orders and Stock Order Items.
# Pass in a Schema, Channel and the number of Stock Orders & Stock Order Items per SO.
sub _create_dummy_po {
    my ( $schema, $channel, $num_so, $num_soi )   = @_;

    my $hash={
        channel_id  => $channel->id,
        placed_by   => 'stock order test',
        stock_order => my $sos = [],
        type_id     => $PURCHASE_ORDER_TYPE__FIRST_ORDER,
        currency_id => $CURRENCY__GBP,
        season_id   => $SEASON__FW10,
        status_id   => $STOCK_ORDER_STATUS__ON_ORDER,
    };

    for my $so_num (1..$num_so) {
        push @$sos, {
            status_id         => $STOCK_ORDER_STATUS__ON_ORDER,
            type_id           => $STOCK_ORDER_TYPE__MAIN,
            shipment_window_type_id => $SHIPMENT_WINDOW_TYPE__UNKNOWN,
            product         => {
                variant             => my $vars = [],
                product_channel     => [{
                    channel_id          => $channel->id,
                }],
                product_attribute   => {
                    description         => 'New Description',
                    name                => 'Test Product Name',
                },
                price_purchase      => {},
            },
        };
        my @sizes=Test::XTracker::Data->get_some_sizes($num_soi);
        for my $var_num (1..$num_soi) {
            push @$vars,{
                size_id   => (shift @sizes)->id,
                quantity  => 10,
                stock_order_item => {
                    status_id => $STOCK_ORDER_ITEM_STATUS__ON_ORDER,
                    type_id   => $STOCK_ORDER_ITEM_TYPE__UNKNOWN,
                },
            };
        }
    };

    my $purchase_order = Test::XTracker::Data->create_from_hash($hash);

    note "PO Number: ".$purchase_order->purchase_order_number;

    return $purchase_order;
}

# set-up a delivery for a stock order, useful to have but not needed yet
# and also not finished, but left here because it could be useful.
sub _setup_delivery_for_so {
    my ( $schema, $stock_order, $num_soi, $delivered )    = @_;

    my $time        = time();

    my ($delivery) = $schema->resultset('Public::Delivery')->create({
        invoice_nr => 'Test Data ' . $time,
        status_id  => ( $delivered ? $DELIVERY_STATUS__COMPLETE : $DELIVERY_STATUS__NEW ),
        type_id    => $DELIVERY_TYPE__STOCK_ORDER,
        cancel     => 0,
     });

    $schema->resultset('Public::LinkDeliveryStockOrder')->create({
        delivery_id    => $delivery->id(),
        stock_order_id => $stock_order->id(),
    });

    my $so_items    = $stock_order->stock_order_items->search( undef, { order_by => 'me.id' } );
    my $counter     = 1;
    while ( my $so_item = $so_items->next ) {
        my ($delivery_item) = $schema->resultset('Public::DeliveryItem')->create({
            delivery_id  => $delivery->id(),
            quantity     => ( $delivered ? $so_item->quantity : 0 ),
            packing_slip => ( $delivered ? $so_item->quantity : 0 ),
            status_id    => ( $delivered ? $DELIVERY_ITEM_STATUS__COMPLETE : $DELIVERY_ITEM_STATUS__NEW ),
            type_id      => $DELIVERY_ITEM_TYPE__STOCK_ORDER,
            cancel       => 0,
        });

        $schema->resultset('Public::LinkDeliveryItemStockOrderItem')->create({
            delivery_item_id    => $delivery_item->id(),
            stock_order_item_id => $so_item->id()
        });

        # if reached the number of stock order items to deliver
        # then stop, unless number was zero then just do all
        if ( $num_soi && $counter >= $num_soi ) {
            last;
        }
        $counter++;
    }

    return $delivery->id;
}

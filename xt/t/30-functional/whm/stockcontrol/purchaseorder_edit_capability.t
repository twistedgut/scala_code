#!/usr/bin/env perl

=head1 NAME

purchaseorder_edit_capability.t - Test editable purchase orders

=head1 DESCRIPTION

Create a Purchase Order (PO).

Checking if the PO is editable.

Check if the product's sizing scheme is editable.

NOTE: The editing capabilities of a specific product size scheme directly
depend on whether or not its PO is editable.

#TAGS inventory purchaseorder loops xpath whm

=cut

use NAP::policy "tt", qw/ test /;

use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::Builder::Tester;
use Data::Dump 'pp';
use XTracker::Config::Local "enable_edit_purchase_order";

my $mech = Test::XTracker::Mechanize->new;
Test::XTracker::Data->set_department('it.god', 'Finance');
Test::XTracker::Data->grant_permissions ('it.god', 'Stock Control', 'Purchase Order', 3);

$mech->do_login;

my $schema = Test::XTracker::Data->get_schema();
my $channel = Test::XTracker::Data->get_local_channel();
my $size_ids = Test::XTracker::Data->find_valid_size_ids(2);

my $purchase_order = Test::XTracker::Data->create_from_hash({
    placed_by       => 'Guy that places these things',
    stock_order     => [{
        product         => {
            product_type_id => 6,
            style_number    => 'Fancy style 123',
            variant         => [{
                size_id         => $size_ids->[0],
                stock_order_item    => {
                    quantity            => 40,
                },
            },{
                size_id         => $size_ids->[1],
                stock_order_item    => {
                    quantity            => 33,
                },
            }],
            product_channel => [ { channel_id => $channel->id, } ],
            product_attribute => {
                description     => 'Buy it now!',
            },
            price_purchase => {},
        },
    }],
});

my ($product) = $purchase_order->stock_orders
    ->related_resultset('stock_order_items')
    ->related_resultset('variant')
    ->related_resultset('product')
    ->all;

for my $editable_in_xt ( 0, 1 ) {
  SKIP: {
    if(!$editable_in_xt && enable_edit_purchase_order){
        skip "Will not test if a PO is not editable if enable_edit_purchase_order flag is set to true",1;
    }

    # If we want the PO to be editable in XT, we need to set the proper flag on the database
    if(!$editable_in_xt){

        # At this point the PO should not be editable
        $mech->get_ok('/StockControl/PurchaseOrder/Overview?po_id=' . $purchase_order->id );
        isnt($purchase_order->is_editable_in_xt,1,"Not editable");
    }else{
        my $po_editable = $schema->resultset('Public::PurchaseOrderNotEditableInFulcrum')->create(
            {
            number => $purchase_order->purchase_order_number
            }
        );

        # The PO should now be editable
        $mech->get_ok('/StockControl/PurchaseOrder/Overview?po_id=' . $purchase_order->id );
        is($purchase_order->is_editable_in_xt,1,"Editable");
    }

    # Now that we fetched the overview page is time to see if the editing buttons are there or not

    for my $xpath_test (
        [
            "//div[\@id=\"contentLeftCol\"]/ul//li/a[\@href=\"/StockControl/PurchaseOrder/Edit?po_id=". $purchase_order->id . "\"]",
            "Edit link"
        ],
        [
            "//div[\@id=\"contentLeftCol\"]/ul//li/a[\@href=\"/StockControl/PurchaseOrder/Confirm?po_id=".$purchase_order->id . "\"]",
            "Confirm link"
        ],
        [
            "//div[\@id=\"contentLeftCol\"]/ul//li/a[\@href=\"/StockControl/PurchaseOrder/ReOrder?po_id=".$purchase_order->id . "\"]",
            "ReOrder link"
        ],
      )
    {
        # Depending on whether we want to edit the PO or not, we should see 0 or 1 edit links of each type
        my $po_links = $mech->find_xpath( $xpath_test->[0] );
        is( $po_links->size, $editable_in_xt ? 1 : 0, $xpath_test->[1] );
    }

    # Test if links actually work - if the PO allows editing, they should work, otherwise not.

    for('Edit','Confirm','ReOrder'){
        my $url = '/StockControl/PurchaseOrder/'.$_.'?po_id='. $purchase_order->id;
        note "Testing if URL $url". ($editable_in_xt ? " is successfully feched " : " fails to fetch");
        if(!$editable_in_xt){
            $mech->get( $url );
            isnt($mech->success, 1, " failed as expected");
        }else{
            $mech->get_ok( $url );
        }
    }

    # Adding permissions to it.god for Inventory control

    Test::XTracker::Data->grant_permissions ('it.god', 'Stock Control', 'Inventory', 1);

    # Visiting the Sizing page for the first PID belonging to this PO to see if it allows size schemes.

    note "Visiting /StockControl/Inventory/Sizing?product_id=".$product->id;

    $mech->get("/StockControl/Inventory/Sizing?product_id=".$product->id);
    my $edit_size_scheme_dropdowns = $mech->find_xpath( '//select[@name="size_scheme_id"]' );
    my $edit_size_dropdowns = $mech->find_xpath( '//select[@name=~"size_id_"]' );
    if(!$editable_in_xt){
        is($edit_size_scheme_dropdowns->size,0, "Expecting to find no dropdowns for the size scheme");
        is($edit_size_dropdowns->size,0, "Expecting to find no dropdowns for the sizing tables");
    }else{
        is($edit_size_scheme_dropdowns->size,1, "Expecting to find one dropdown for the size scheme");
        cmp_ok($edit_size_dropdowns->size,'>',0, "Expecting to find at least one dropdown for the sizing tables");
    }
  }
}

done_testing;

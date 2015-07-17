#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 rma_split_renum.t

This essentially tests that when a Return with Multiple Items is checked in and not all of
the items pass Return QC, that those items that do pass are split off onto their own
Renumeration and then 'Completed' so that the Customer is Refunded for those items that have
passed immediately while the other items are investigated.

This tests runs through the following scenario:

# STAGE 1
    * A Return (RMA) for 4 items is created
        -> a Renumeration will be created for all 4 items.
    * Returns In page: Book In 3 out of the 4 items
    * Returns QC page: Pass QC 1 item, Fail QC 2 items
        -> this should result in the Pass QC item being split off onto
           its own Renumeration and that Renumeration being Completed.
        -> because there is still one item Awaiting Return the Failed
           items should also be split off onto their own Renumeration
           but its status should be 'Pending'.
    * Returns Faulty page:
        * Accept 1 item and send the item to 'Main Stock'
        * Reject the other item and send the item to 'Dead Stock'
            -> this should result in the Rejected item being deleted from
               the 'Failed' Renumeration and then as 1 item was Accepted
               the Renumeration should be 'Completed'.

# STAGE 2
    * Returns In page: Book in the last remaining item
    * Returns QC page: Fail QC the last item
        -> as this is the last item and the original Renumeration
           only has this item for it then NOTHING will be split off.
    * Returns Faulty page: Accept the last item
        -> the original Renumeration should be 'Completed'.

=cut

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XT::Flow;

use XTracker::Constants::FromDB qw/
  :stock_process_status
  :authorisation_level
  :customer_issue_type
  :renumeration_status
  :return_status
  :return_item_status
  :shipment_item_status
/;


# go get some pids relevant to the db I'm using - channel is for test context
my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 4,
    ensure_stock_all_variants => 1,
});

my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
    pids => $pids,
    attrs => [
        { price => 250.00 },
        { price => 100.00 },
        { price => 50.00 },
        { price => 25.00 },
    ],
});

my $order_nr = $order->order_nr;
ok( my $shipment = $order->shipments->first, "Sanity check: the order has a shipment" );
my @items   = $shipment->shipment_items->search( {}, { order_by => 'id' } )->all;

note "Order Nr: $order_nr";

my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::PrintStation',
    ],
);

Test::XTracker::Data->set_department('it.god', 'Customer Care');
$framework->login_with_permissions( {
    perms => {
        $AUTHORISATION_LEVEL__OPERATOR => [
            'Customer Care/Order Search',
            'Customer Care/Customer Search',
            'Goods In/Returns In',
            'Goods In/Returns QC',
            'Goods In/Returns Faulty',
        ],
    }
} );

my $mech    = $framework->mech;
$mech->force_datalite(1);

my $return;
my $ri;

$mech->order_nr($order_nr);

my $amq     = Test::XTracker::MessageQueue->new;
my $queue   = $mech->nap_order_update_queue_name();
$amq->clear_destination( $queue );

my $schema = $order->result_source->schema;

my $reason  = $schema->resultset('Public::CustomerIssueType')->find( $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL );

my @products_to_return  = map {
    {
        sku             => $_->get_sku,
        selected        => 1,
        return_type     => 'Return',
        return_reason   => $reason->description,
    }
} @items;


##
## STAGE 1
##

#
# Create Return
#

$framework->flow_mech__customercare__orderview( $order->id )
            ->flow_mech__customercare__view_returns
              ->flow_mech__customercare__view_returns_create_return
                ->flow_mech__customercare__view_returns_create_return_data( { products => \@products_to_return } )
                  ->flow_mech__customercare__view_returns_create_return_submit( { send_email => 'no' } )
;
$return = $shipment->returns->first;
# get the return items in Shipment Item Id to complement the order of Shipment Items
my @return_items = $return->return_items->search( {}, { order_by => 'shipment_item_id' } )->all;


#
# Book In only 3 of the 4 Items for the Return
#

_set_returns_printer_station( $framework, $channel, 'ReturnsIn' );
$framework->flow_mech__goodsin__returns_in_submit( $return->rma_number );
# only Book in the first TWO items leaving the last as 'Awaiting Return'
$framework->flow_mech__goodsin__returns_in__book_in( $_->{sku} )
                                            foreach ( @products_to_return[0..2] );
$framework->flow_mech__goodsin__returns_in__complete_book_in('2222222222','no');
my $delivery    = $return->deliveries->first;


#
# Returns QC page
#

# QC the Return Items using the Stock Process Id
# Pass the first Item and Fail the second and third,
# this should split these items onto 2 New Renumerations
my %qc_items = (
    $return_items[0]->incomplete_stock_process->id => {
        decision    => 'pass',
        test_debug_message => 'for SKU: ' . $return_items[0]->variant->sku,
    },
    $return_items[1]->incomplete_stock_process->id => {
        decision    => 'fail',
        test_debug_message => 'for SKU: ' . $return_items[1]->variant->sku,
    },
    $return_items[2]->incomplete_stock_process->id => {
        decision    => 'fail',
        test_debug_message => 'for SKU: ' . $return_items[2]->variant->sku,
    },
);
_set_returns_printer_station( $framework, $channel, 'ReturnsQC' );
$framework->flow_mech__goodsin__returns_qc
            ->flow_mech__goodsin__returns_qc_submit( $delivery->id )
              ->flow_mech__goodsin__returns_qc__process_item_by_item( \%qc_items )
;

# check for correct Statuses
cmp_ok( $return->discard_changes->return_status_id, '==', $RETURN_STATUS__PROCESSING, "Return status is still 'Processing'" );
cmp_ok( $return_items[0]->discard_changes->return_item_status_id, '==', $RETURN_ITEM_STATUS__PASSED_QC, "First Item Passed QC" );
cmp_ok( $return_items[1]->discard_changes->return_item_status_id, '==', $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION, "Second Item Failed QC" );
cmp_ok( $return_items[2]->discard_changes->return_item_status_id, '==', $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION, "Third Item Failed QC" );
cmp_ok( $return_items[3]->discard_changes->return_item_status_id, '==', $RETURN_ITEM_STATUS__AWAITING_RETURN, "Fourth Item still Awaiting Return" );

# get all Renumerations for the Return, they should come out in the
# following Order: Original, New for Passed item, New for Failed items
my @renumeration = $return->renumerations->not_cancelled->search( {}, { order_by => 'id' } )->all;

# Check we have the correct number of non-cancelled renumerations.
cmp_ok( scalar @renumeration, '==', 3, 'Return has three renumerations' );

note "Test original renumeration";
cmp_ok( $renumeration[0]->sent_to_psp, '==', 0, 'Renumeration HAS NOT been Sent To PSP' );
cmp_ok( $renumeration[0]->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, 'Renumeration status is PENDING' );
cmp_ok( $renumeration[0]->renumeration_items->count, '==', 1, "Renumeration only has ONE item" );
cmp_ok( $renumeration[0]->renumeration_items->first->shipment_item_id, '==', $items[3]->id, "Renumeration Item is for the Correct Shipment Item" );
cmp_ok( $renumeration[0]->renumeration_items->first->unit_price, '==', $items[3]->unit_price, "Renumeration Item Unit Price is as Expected" );

note "Test newly created renumeration for Passed QC item";
cmp_ok( $renumeration[1]->sent_to_psp, '==', 1, 'Renumeration HAS been Sent To PSP' );
cmp_ok( $renumeration[1]->renumeration_status_id, '==', $RENUMERATION_STATUS__COMPLETED, 'Renumeration status is COMPLETED' );
cmp_ok( $renumeration[1]->renumeration_items->count, '==', 1, "Renumeration only has ONE item" );
cmp_ok( $renumeration[1]->renumeration_items->first->shipment_item_id, '==', $items[0]->id, "Renumeration Item is for the Correct Shipment Item" );
cmp_ok( $renumeration[1]->renumeration_items->first->unit_price, '==', $items[0]->unit_price, "Renumeration Item Unit Price is as Expected" );

note "Test newly created renumeration for Failed QC item";
cmp_ok( $renumeration[2]->sent_to_psp, '==', 0, 'Renumeration HAS NOT been Sent To PSP' );
cmp_ok( $renumeration[2]->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, 'Renumeration status is PENDING' );
cmp_ok( $renumeration[2]->renumeration_items->count, '==', 2, "Renumeration only has TWO items" );
my @renum_items = $renumeration[2]->renumeration_items->search( {}, { order_by => 'shipment_item_id' } )->all;
cmp_ok( $renum_items[0]->shipment_item_id, '==', $items[1]->id, "First Renumeration Item is for the Correct Shipment Item" );
cmp_ok( $renum_items[0]->unit_price, '==', $items[1]->unit_price, "First Renumeration Item Unit Price is as Expected" );
cmp_ok( $renum_items[1]->shipment_item_id, '==', $items[2]->id, "Second Renumeration Item is for the Correct Shipment Item" );
cmp_ok( $renum_items[1]->unit_price, '==', $items[2]->unit_price, "Second Renumeration Item Unit Price is as Expected" );


#
# Returns Faulty page
#

# now Accept one of the Faulty items and Reject
# the other, this should mean the rejected one
# being removed from the Renumeration and then
# that Renumeration should be Complete

# a new Stock Process record would have been created when the item was 'Failed'
my $stock_process   = $return_items[1]->incomplete_stock_process;
$framework->flow_mech__goodsin__returns_faulty
            ->flow_mech__goodsin__returns_faulty_submit( $stock_process->group_id )
              ->flow_mech__goodsin__returns_faulty_decision('accept')
;
cmp_ok( $stock_process->discard_changes->status_id, '==', $STOCK_PROCESS_STATUS__NEW, "Stock Process for Failed Item is still NEW" );
cmp_ok( $return_items[1]->discard_changes->return_item_status_id, '==', $RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED,
                                    "First Failed Item now Accepted" );
cmp_ok( $return_items[2]->discard_changes->return_item_status_id, '==', $RETURN_ITEM_STATUS__FAILED_QC__DASH__AWAITING_DECISION,
                                    "Second Failed Item still Awaiting Decision" );

note "Test renumeration for Failed QC items again, should still be Pending as there is one item left to Accept/Reject";
cmp_ok( $renumeration[2]->discard_changes->renumeration_items->count, '==', 2, "Renumeration still has TWO items" );
cmp_ok( $renumeration[2]->sent_to_psp, '==', 0, 'Renumeration still HAS NOT been Sent To PSP' );
cmp_ok( $renumeration[2]->renumeration_status_id, '==', $RENUMERATION_STATUS__PENDING, 'Renumeration status is still PENDING' );

# make the decision to return the item to Main Stock
$framework->flow_mech__goodsin__returns_faulty_process('Return to Stock');
cmp_ok( $stock_process->discard_changes->status_id, '==', $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED, "Stock Process for Failed Item now BAGGED AND TAGGED" );

# now Reject the Second Item
$stock_process  = $return_items[2]->discard_changes->incomplete_stock_process;
$framework->flow_mech__goodsin__returns_faulty_submit( $stock_process->group_id )
            ->flow_mech__goodsin__returns_faulty_decision('reject')
;
cmp_ok( $stock_process->discard_changes->status_id, '==', $STOCK_PROCESS_STATUS__NEW, "Stock Process for Failed Item is still NEW" );
cmp_ok( $return_items[1]->discard_changes->return_item_status_id, '==', $RETURN_ITEM_STATUS__FAILED_QC__DASH__FIXED,
                                    "First Failed Item Fixed" );
cmp_ok( $return_items[2]->discard_changes->return_item_status_id, '==', $RETURN_ITEM_STATUS__FAILED_QC__DASH__REJECTED,
                                    "Second Failed Item now Rejected" );

note "Test renumeration for Failed QC items again, should now be Complete and only be for ONE item";
cmp_ok( $renumeration[2]->discard_changes->renumeration_items->count, '==', 1, "Renumeration now has only ONE item" );
cmp_ok( $renumeration[2]->sent_to_psp, '==', 1, 'Renumeration HAS been Sent To PSP' );
cmp_ok( $renumeration[2]->renumeration_status_id, '==', $RENUMERATION_STATUS__COMPLETED, 'Renumeration status is COMPLETED' );
cmp_ok( $renumeration[2]->renumeration_items->first->shipment_item_id, '==', $items[1]->id,
                                    "and its only Renumeration Item is for the Correct Shipment Item" );

# make the decision to send the item to Dead Stock
$framework->flow_mech__goodsin__returns_faulty_process('Dead Stock');
cmp_ok( $stock_process->discard_changes->status_id, '==', $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED, "Stock Process for Failed Item now BAGGED AND TAGGED" );

# the Return process should still be Processing because there is one more item still to be Returned
cmp_ok( $return->discard_changes->return_status_id, '==', $RETURN_STATUS__PROCESSING, "Return Status is still Processing" );


##
## STAGE 2
##

#
# Returns In page
#

note "Now Book In & QC the last item making sure everything gets Completed";
_set_returns_printer_station( $framework, $channel, 'ReturnsIn' );
$framework->flow_mech__goodsin__returns_in_submit( $return->rma_number )
            ->flow_mech__goodsin__returns_in__book_in( $products_to_return[3]->{sku} )
              ->flow_mech__goodsin__returns_in__complete_book_in('3333333333','no')
;


#
# Returns QC page
#

# get the latest delivery
$delivery   = $return->deliveries->search( {}, { order_by => 'id DESC' } )->first;
_set_returns_printer_station( $framework, $channel, 'ReturnsQC' );
$framework->flow_mech__goodsin__returns_qc
            ->flow_mech__goodsin__returns_qc_submit( $delivery->id )
              ->flow_mech__goodsin__returns_qc__process_item_by_item( {
                    $return_items[3]->discard_changes->incomplete_stock_process->id => {
                        decision    => 'fail',
                        test_debug_message => 'for SKU: ' . $return_items[3]->variant->sku,
                    },
              } )
;


#
# Returns Faulty page
#

$stock_process  = $return_items[3]->discard_changes->incomplete_stock_process;
$framework->flow_mech__goodsin__returns_faulty
            ->flow_mech__goodsin__returns_faulty_submit( $stock_process->group_id )
              ->flow_mech__goodsin__returns_faulty_decision('accept')
;
cmp_ok( $return->discard_changes->renumerations->count, '==', 3, "There are still only THREE Renumerations" );
cmp_ok( $renumeration[0]->discard_changes->sent_to_psp, '==', 1, 'Original Renumeration HAS now been Sent To PSP' );
cmp_ok( $renumeration[0]->renumeration_status_id, '==', $RENUMERATION_STATUS__COMPLETED, 'Renumeration status is now COMPLETE' );
cmp_ok( $renumeration[0]->renumeration_items->count, '==', 1, "Renumeration still only has ONE item" );

cmp_ok( $return_items[3]->discard_changes->return_item_status_id, '==', $RETURN_ITEM_STATUS__FAILED_QC__DASH__ACCEPTED,
                                            "Fourth Item now Failed QC Accepted" );
cmp_ok( $return->return_status_id, '==', $RETURN_STATUS__COMPLETE, "Return Status is now Complete" );


done_testing;

#----------------------------------------------------------------------------

sub _set_returns_printer_station {
    my ( $framework, $channel, $type )  = @_;

    $framework->flow_mech__goodsin__returns_in
                ->flow_mech__select_printer_station( {
                    section     => 'GoodsIn',
                    subsection  => $type,
                    channel_id  => $channel->id,
                } )
    ;

    $framework->flow_mech__select_printer_station_submit;

    return $framework;
}


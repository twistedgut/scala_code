#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 NAME

cancel_shipment_item.t - Cancel a Shipment Item and for Pre-Order Refund the Customer as well

=head1 DESCRIPTION

This tests to see that one or more Shipment Items can be Cancelled and that if
the Order is for a Pre-Order then a Refund is generated and an attempt to Refund
the Customer is made.

This uses the 'Cancel Shipment Item' Left Hand Menu link on the
Order View page to:

   * Cancel 1 of 4 items
   * Cancel 2 more items
   * Cancel the remaining item and get an error message
     directing the user to use the 'Cancel Order' option
   * For a Pre-Order check a Refund Invoice is created
   * For a Normal Order that NO Refund Invoice is created
   * Check the details for the Cancel Item Email is correct on the page

#TAGS inventory preorder fulfiment cancel cancelorder orderview cancelpreorder cando

=cut

use DateTime::Duration;

use Test::XTracker::Hacks::isaFunction;
use Test::MockObject;

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::PSP;
use Test::XTracker::Page::Elements::Form;
use Test::XT::Flow;

use XTracker::Constants                 qw( :application );
use XTracker::Config::Local             qw( customercare_email);
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :customer_issue_type
                                            :shipment_status
                                            :shipment_item_status
                                            :renumeration_class
                                            :renumeration_type
                                            :order_status
                                        );
use XTracker::Config::Local qw( config_var );


my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
);

#---------- run tests ----------
_cancel_a_pre_order_order_shipment_items( $framework );
_cancel_order_shipment_items( $framework );
#-------------------------------

done_testing();


=head1 METHODS

=head2 _cancel_a_pre_order_order_shipment_items

    _cancel_a_pre_order_order_shipment_items( $framework );

Test Cancelling Shipment Items for an Order that is linked to a Pre-Order.

=cut

sub _cancel_a_pre_order_order_shipment_items {
    my ( $framework ) = @_;

    note "TESTING '_cancel_a_pre_order_order_shipment_items' function";

    my $order       = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order( { order_item_counts => [ 4 ] } );
    my $shipment    = $order->get_standard_class_shipment;
    my @items       = $shipment->shipment_items->search( {}, { order_by => 'me.id' } )->all;
    _clear_out_renumerations_for_shipment( $shipment );

    $framework->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__OPERATOR => [
                'Customer Care/Customer Search',
                'Customer Care/Order Search',
            ]
        },
        dept => 'Customer Care',
    } );

    note "Cancel ONE Shipment Item";
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__cancel_shipment_item;
    my $pg_data = $framework->mech->as_data->{cancel_item_form};
    _select_resultset_ok( $framework );
    is( $pg_data->{refund_option}{Type}{value}, 'Card Refund',
                            "Only 'Card Refund' refund option shown, for a Pre-Order Order" );

    $framework->flow_mech__customercare__cancel_item_submit(
                                    [ $items[0]->id   => qr/Card Blocked/i ],
                                );
    $framework->mech->log_snitch->pause;        # pause because of known error with connecting to the PSP
    $framework->flow_mech__customercare__cancel_item_email_submit;
    $framework->mech->log_snitch->unpause;

    $framework->mech->has_feedback_success_ok( qr/Shipment item has been cancelled/, "SUCCESS Message Displayed" );
    $framework->mech->has_feedback_info_ok( qr/Customer has NOT been Refunded.*should now go to Finance to Complete/i,
                                                    "Couldn't Refund INFO Message Displayed" );

    _check_cancel_ok( $order, { cancelled_items => [ $items[0] ] } );
    _clear_out_renumerations_for_shipment( $shipment );

    note "Cancel TWO Shipment Items";
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__cancel_shipment_item
                    ->flow_mech__customercare__cancel_item_submit(
                                    [ $items[3]->id => qr/Card Blocked/i ],
                                    [ $items[1]->id => qr/Card Blocked/i ],
                                );
    $framework->mech->log_snitch->pause;        # pause because of known error with connecting to the PSP
    $framework->flow_mech__customercare__cancel_item_email_submit;
    $framework->mech->log_snitch->unpause;

    $framework->mech->has_feedback_success_ok( qr/Shipment items have been cancelled/, "SUCCESS Message Displayed" );
    $framework->mech->has_feedback_info_ok( qr/Customer has NOT been Refunded.*should now go to Finance to Complete/i,
                                                    "Couldn't Refund INFO Message Displayed" );

    _check_cancel_ok( $order, {
                                cancelled_items => [ @items[3,1] ],
                                already_cancelled_items => [ $items[0] ]
                            } );

    note "Attempt to Cancel ALL of the rest of the Items";
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__cancel_shipment_item;
    $framework->errors_are_fatal(0);
    $framework->flow_mech__customercare__cancel_item_submit(
                                    [ $items[2]->id => qr/Card Blocked/i ],
                                );
    $framework->errors_are_fatal(1);

    $framework->mech->content_like(
                qr/selected all of the items in the shipment for cancellation, please use the "Cancel Shipment" or "Cancel Order"/i,
                "Got 'Use Cancel Order Instead' message when trying to Cancel All of Items"
            );
    return $framework;
}

=head2 _cancel_order_shipment_items

    _cancel_order_shipment_items( $framework );

Test Cancelling Shipment Items for an Order.

=cut

sub _cancel_order_shipment_items {
    my ( $framework ) = @_;

    note "TESTING '_cancel_order_shipment_items' function";

    note "Create an Order with a Card Debit";
    my $order       = _create_an_order('card_debit');
    my $shipment    = $order->get_standard_class_shipment;
    my @items       = $shipment->shipment_items->search( {}, { order_by => 'me.id' } )->all;
    _clear_out_renumerations_for_shipment( $shipment );

    $framework->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__OPERATOR => [
                'Customer Care/Customer Search',
                'Customer Care/Order Search',
            ]
        },
        dept => 'Customer Care',
    } );

    note "Try Cancelling an Item when Payment has been Fulfilled shouldn't be allowed";
    my $payment = $order->payments->first;
    $payment->update( { fulfilled => 1 } );
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__cancel_shipment_item;
    $framework->mech->content_like( qr/too late to cancel items from this shipment, it has already begun the dispatch/i,
                                                "Got 'Too Late' message" );
    $payment->update( { fulfilled => 0 } );

    note "Cancel ONE Shipment Item";
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__cancel_shipment_item;
    my $pg_data = $framework->mech->as_data->{cancel_item_form};
    _select_resultset_ok( $framework );
    ok( !exists( $pg_data->{refund_option} ), "NO Refund Options Shown to User when Card Debit used to Pay" );

    $framework->flow_mech__customercare__cancel_item_submit(
                                    [ $items[0]->id => qr/Card Blocked/i ],
                                );

    note "testing email content";
    $pg_data = $framework->mech->as_data();
    my $from_address = customercare_email( $order->channel->business->config_section, {
            schema  => $framework->schema,
            locale  => $order->customer->locale,
    } );

    my $email_form  = $pg_data->{email_form};
    is( $email_form->{To}{input_value}, $order->email, "To address is as expected :". $order->email);
    is( $email_form->{From}{input_value}, $from_address,"From address is as expected: ".${from_address} );
    is( $email_form->{'Reply-To'}{input_value}, $from_address,"Reply-To address is as expected: '${from_address}'" );
    cmp_ok( length($email_form->{'Subject'}{'input_value'} ) ,'>' ,0 ,"Subject is not null as expected");
    cmp_ok( length($email_form->{'Email Text'}{'value'} ) ,'>' ,0 ,"Email contet is not null as expected");
    cmp_ok( $email_form->{'Email Text'}{'input_name'}, 'eq', 'email_content_type', "Email content_type exists");
    cmp_ok( length($email_form->{'Email Text'}{'input_value'} ) ,'>' ,0 ,"Email content_type is not null as expected");


    $framework->flow_mech__customercare__cancel_item_email_submit;

    $framework->mech->has_feedback_success_ok( qr/Shipment item has been cancelled/, "SUCCESS Message Displayed" );
    _check_cancel_ok( $order, { cancelled_items => [ $items[0] ] } );

    note "Cancel TWO Shipment Items";
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__cancel_shipment_item
                    ->flow_mech__customercare__cancel_item_submit(
                                    [ $items[3]->id => qr/Card Blocked/i ],
                                    [ $items[1]->id => qr/Card Blocked/i ],
                                )
                        ->flow_mech__customercare__cancel_item_email_submit;

    $framework->mech->has_feedback_success_ok( qr/Shipment items have been cancelled/, "SUCCESS Message Displayed" );
    _check_cancel_ok( $order, {
                                cancelled_items => [ @items[3,1] ],
                                already_cancelled_items => [ $items[0] ]
                            } );

    note "Create an Order with a Store Credit";
    $order      = _create_an_order('store_credit');
    $shipment   = $order->get_standard_class_shipment;
    @items      = $shipment->shipment_items->search( {}, { order_by => 'me.id' } )->all;
    _clear_out_renumerations_for_shipment( $shipment );

    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__cancel_shipment_item;
    $pg_data    = $framework->mech->as_data->{cancel_item_form};
    ok( exists( $pg_data->{refund_option}{Type}{select_name} ),
                        "A Drop Down of Refund Options is Shown to the User When Store Credit is used to Pay" );

    $framework->flow_mech__customercare__cancel_item_submit(
                                    [ $items[2]->id => qr/Card Blocked/i ],
                                )
                ->flow_mech__customercare__cancel_item_email_submit;

    $framework->mech->has_feedback_success_ok( qr/Shipment item has been cancelled/, "SUCCESS Message Displayed" );
    _check_cancel_ok( $order, { cancelled_items => [ $items[2] ] } );

    note "Attempt to Cancell ALL of the rest of the Items";
    $framework->flow_mech__customercare__orderview( $order->id )
                ->flow_mech__customercare__cancel_shipment_item;
    $framework->errors_are_fatal(0);
    $framework->flow_mech__customercare__cancel_item_submit(
                                    [ $items[0]->id => qr/Card Blocked/i ],
                                    [ $items[1]->id => qr/Card Blocked/i ],
                                    [ $items[3]->id => qr/Card Blocked/i ],
                                );
    $framework->errors_are_fatal(1);

    $framework->mech->content_like(
                qr/selected all of the items in the shipment for cancellation, please use the "Cancel Shipment" or "Cancel Order"/i,
                "Got 'Use Cancel Order Instead' message when trying to Cancel All of Items"
            );
    return $framework;
}

#-----------------------------------------------------------------

=head2 _check_cancel_ok

    _check_cancel_ok( $dbic_order_or_shipment, $args );

Test Helper to make sure the order & shipment have been properly cancelled.

=cut

sub _check_cancel_ok {
    my ( $record, $args )   = @_;

    my @already_cancelled_item_ids  = map { $_->id } @{ $args->{already_cancelled_items} };
    my @cancelled_item_ids          = map { $_->id } @{ $args->{cancelled_items} };

    my $order;
    my $shipment;

    if ( ref( $record->discard_changes ) =~ m/Public::Shipment/ ) {
        # if record is a Shipment object
        $shipment   = $record;
        $order      = $shipment->order;
    }
    else {
        # otherwise assume it's and Order object
        $order      = $record;
        $shipment   = $order->get_standard_class_shipment;
    }

    cmp_ok( $order->discard_changes->order_status_id, '==', $ORDER_STATUS__ACCEPTED, "Order Status Still Accepted" );
    cmp_ok( $shipment->discard_changes->shipment_status_id, '==', $SHIPMENT_STATUS__PROCESSING, "Shipment Status Still Processing" );

    # get Cancelled, Already Cancelled & Non-Cancelled Items
    my $cancel_items_rs     = $shipment->shipment_items->search( { id => { 'in' => \@cancelled_item_ids } } );
    my $still_cancel_items_rs = $shipment->shipment_items->search( { id => { 'in' => \@already_cancelled_item_ids } } );
    my $non_cancel_items_rs = $shipment->shipment_items->search( {
                                                            id => { 'not in' => [ @cancelled_item_ids, @already_cancelled_item_ids ] },
                                                        } );

    # check Cancelled
    foreach my $item ( $cancel_items_rs->all ) {
        cmp_ok( $item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED,
                                                        "Shipment Item (".$item->id.") Status Cancelled" );
    }
    # check Already Cancelled
    foreach my $item ( $still_cancel_items_rs->all ) {
        cmp_ok( $item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED,
                                                        "Shipment Item (".$item->id.") Status Still Cancelled" );
    }
    # check NOT Cancelled
    foreach my $item ( $non_cancel_items_rs->all ) {
        cmp_ok( $item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__NEW,
                                                        "Shipment Item (".$item->id.") Status Still New" );
    }

    my $payment = $order->payments->first;

    if ( $order->has_preorder ) {
        cmp_ok( $payment->valid, '==', 1, "'orders.payment' record is still Valid" );

        my $ship_value  = $shipment->shipping_charge
                          + $cancel_items_rs->get_column('unit_price')->sum || 0
                          + $cancel_items_rs->get_column('tax')->sum || 0
                          + $cancel_items_rs->get_column('duty')->sum || 0;

        my $renum   = $shipment->refund_renumerations->search( {}, { order_by => 'id DESC' } )->first;
        ok( defined $renum, "Shipment has a Refund Invoice" );
        cmp_ok( $renum->renumeration_class_id, '==', $RENUMERATION_CLASS__CANCELLATION, "Refund Class is Cancellation" );
        cmp_ok( $renum->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_REFUND, "Refund Type is Card Refund" );
        cmp_ok( $renum->grand_total, '==', $ship_value, "Refund Value is as expected: $ship_value" );
        cmp_ok( $renum->store_credit, '==', 0, "Store Credit Value is ZERO" );
        cmp_ok( $renum->sent_to_psp, '==', 1, "'sent_to_psp' flag is TRUE" );
    }
    else {
        cmp_ok( $shipment->refund_renumerations->count, '==', 0, "NO Refund Renumerations have been Created" );

        if( $payment ) {

            my $threshold = config_var( 'Valid_Payments', 'valid_payments_threshold' ) * 0.01;
            my $max = abs($order->pre_auth_total_value * (1 + $threshold ));
           if(abs($order->get_total_value) > $max ) {
               cmp_ok( $payment->valid, '==', 0, "'orders.payment' record is Now Invalid" );
           } else {
               cmp_ok ($payment->valid, "==", 1 , "'orders.payment' record is Now Valid");
           }
        }

    }

    return;
}

#-----------------------------------------------------------------------------

=head2 _create_an_order

    $dbic_order = _create_an_order( $tender_type );

Helper to create an Order with a Payment record.

=cut

sub _create_an_order {
    my $tender_type     = shift;

    # create an Order
    my $orddetails  = $framework->flow_db__fulfilment__create_order(
        channel  => Test::XTracker::Data->channel_for_nap,
        products => 4,
        tenders => [ { type => $tender_type, value => 410 } ],
    );
    my $order       = $orddetails->{order_object};
    my $shipment    = $orddetails->{shipment_object};
    my $payment;

    note "Order Id/NR: ".$order->id."/".$order->order_nr;
    note "Shipment Id: ".$shipment->id;

    # create the 'orders.payment' record
    if ( $tender_type eq "card_debit" ) {
        my $psp_refs= Test::XTracker::Data->get_new_psp_refs();
        $payment    = Test::XTracker::Data->create_payment_for_order( $order, $psp_refs );
        note "Order Payment Created, Id/Pre-Auth: ".$payment->id."/".$payment->preauth_ref;
    }

    return $order;
}

=head2 _clear_out_renumerations_for_shipment

    _clear_out_renumerations_for_shipment( $dbic_shipment );

Helper to reset Shipment data.

=cut

sub _clear_out_renumerations_for_shipment {
    my $shipment    = shift;

    $shipment->renumerations->search_related('renumeration_items')->delete;
    $shipment->renumerations->search_related('renumeration_status_logs')->delete;
    $shipment->renumerations->search_related('renumeration_tenders')->delete;
    $shipment->renumerations->delete;

    return $shipment->discard_changes;
}

sub _select_resultset_ok {
    my ( $framework ) = @_;

    my @select_items = @{ $framework->mech->as_data->{cancel_item_form}->{select_items} };

    my $cancellation_reasons = $framework->schema
        ->resultset('Public::CustomerIssueType')
        ->cancellation_reasons
        ->search({ id => { '!=' => $CUSTOMER_ISSUE_TYPE__8__STOCK_DISCREPANCY_ON_ONE_ITEM_COMMA__CANCELLED_WHOLE_ORDER } });

    foreach my $select_item ( @select_items ) {

        my @got_reason_dropdown = grep
            { $_->{value} ne '0' }
            @{ $select_item->{reason_for_cancellation} };

        Test::XTracker::Page::Elements::Form
            ->page__elements__form__select_resultset_ok(
                \@got_reason_dropdown,
                scalar $cancellation_reasons,
                'Cancellation reasons displayed as expected'
            );

    }

}

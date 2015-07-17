#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 NAME

cancel_order.t - Cancel the Payment Pre-Auth via the PSP when Cancelling an Order

=head1 DESCRIPTION

This tests to see that a Payment Pre-Auth will be cancelled when an order is
cancelled through the 'Order Cancel' page.

It will test the function '__cancel_shipment' in the
'XTracker::Order::Actions::ChangeOrderStatus' module which actually cancels the
shipment, it will then do a Client test to actually use the page, because we
can't mock the PSP when actually going through the App.

The test can only check that Error messages are displayed once the Order has been
cancelled. This also test Cancelling an Order that has a Pre-Order attached.

This uses the 'Cancel Order Page' option on the Left Hand Menu of the
Order View page and tests:

    * Can't Cancel an Order when the Payment has been fulfilled
    * Checks Cancelling an Order and Pre-Auth is attempted to be Cancelled
    * Checks Cancelling an Order with Store Credit results in a
      Cancellation Store Credit Refund Invoice being generated
    * Checks Cancelling an Order with a Pre-Order attached
      and that NO Pre-Auth is attempted to be Cancelled and
      that a Cancellation Card Refund Invoice is generated
    * Checks the Email details on the page for
      the Cancelled Email that will be sent

#TAGS inventory orderview fulfilment cancel partunit preorder finance needsrefactor cando

=cut

use DateTime::Duration;

use Test::XTracker::Hacks::isaFunction;
use Test::MockObject;

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::PSP;
use Test::XTracker::Data::Email;
use Test::XTracker::Page::Elements::Form;
use Test::XT::Flow;

use XTracker::Constants                 qw( :application );
use XTracker::Config::Local             qw( customercare_email);
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :correspondence_templates
                                            :customer_issue_type
                                            :shipment_status
                                            :shipment_item_status
                                            :renumeration_class
                                            :renumeration_type
                                            :order_status
                                        );

BEGIN {
    no warnings 'redefine';
    use_ok( "XTracker::Order::Actions::ChangeOrderStatus" );
    use_ok( "XTracker::Error" );

    # override the 'xt_feedback' function in 'XTracker::Error' with our own
    *XTracker::Error::xt_feedback = \&_xt_feedback;
}

# Global variable to store what comes through 'xt_feedback'
my $xt_feedback;


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
);

#---------- run tests ----------
_test_cancel_shipment_function( $framework, 1 );
_test_order_cancel_page( $framework, 1 );
_cancel_a_pre_order_order( $framework, 1 );
#-------------------------------

done_testing();


=head1 METHODS

=head2 _test_order_cancel_page

    _test_order_cancel_page( $framework, $ok_to_do_flag );

This will just go through a Client Test to make sure an error message appears
on the page associated with Cancelling the Pre-Auth, as we can't mock the PSP
after the Order has been Cancelled.

=cut

sub _test_order_cancel_page {
    my ( $framework, $oktodo )  = @_;

    SKIP: {
        skip "_test_order_cancel_page", 1   if ( !$oktodo );

        note "TESTING 'Order Cancel' page";

        # 'set_department' should return the Operator Record of the user it's updating
        my $itgod_op    = Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                ]
            }
        } );

        my ( $order, $shipment, $payment )  = _create_an_order( 'card_debit' );

        note "Attempt to Cancel an Order when the Payment has been Fulfilled";
        $payment->update( { fulfilled => 1 } );
        $framework->flow_mech__customercare__cancel_order( $order->id );
        $framework->mech->content_like( qr/too late to cancel this order, it has already begun the dispatch/i,
                                                    "Got 'Too Late' message" );
        $payment->update( { fulfilled => 0 } );

        note "test an order with a Pre-Auth Payment this should show an 'Info' message on the page";
        $framework->flow_mech__customercare__cancel_order( $order->id );

        # We're not interested in the "information" options, i.e. "please
        # select ...".
        my @got_reason_dropdown = grep
            { $_->{value} ne '0' }
            @{ $framework->mech->as_data->{reason_dropdown} };

        Test::XTracker::Page::Elements::Form
            ->page__elements__form__select_resultset_ok(
                \@got_reason_dropdown,
                scalar $framework->schema->resultset('Public::CustomerIssueType')->cancellation_reasons,
                'Cancellation reasons displayed as expected'
            );

        $framework->flow_mech__customercare__cancel_order_submit;

        $framework->mech->log_snitch->pause;        # pause because of known error with connecting to the PSP
        $framework->flow_mech__customercare__cancel_order_email_submit->note_status;
        $framework->mech->log_snitch->unpause;

        $framework->mech->has_feedback_info_ok( qr/This Order has been Cancelled, However a problem/, "INFO Message Displayed" );
        cmp_ok( $payment->preauth_cancelled_failure, '==', 1, "Payment has a Pre-Auth Cancelled Failure" );
        like( $order->order_notes->first->note, qr/context 'Cancelling an Order'/,
                                        "Order Note has expected Context in it 'Cancelling an Order'" );
        cmp_ok( $order->order_notes->first->operator_id, '==', $itgod_op->id,
                                        "Order Note had correct Operator Id" );
        _check_cancel_ok( $order );

        note "test an order with NO Pre-Auth this should show a 'Success' message on the page";
        ( $order, $shipment, $payment ) = _create_an_order( 'store_credit' );

        # change the Email Content so that certain variables can be tested for
        Test::XTracker::Data::Email->overwrite_correspondence_template_content( {
            template_id    => $CORRESPONDENCE_TEMPLATES__CONFIRM_CANCELLED_ORDER,
            type_of_change => 'prepend',
            raw_text       => '[% USE Dumper( Indent=1, Pad="TEST:" ) %][% Dumper.dump(payment_info) %]',
        } );

        $framework->flow_mech__customercare__cancel_order( $order->id )
                    ->flow_mech__customercare__cancel_order_submit;

        # restore the Email Content now it's been shown on the page, do
        # this as early as possible in case the following tests crash
        Test::XTracker::Data::Email->restore_correspondence_template_content();

        note "check email content ";

        my $pg_data = $framework->mech->as_data();

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

        # check the email has 'payment_info' parts available to it
        my $email_text = $email_form->{'Email Text'}{'value'};
        like( $email_text, qr/TEST:\s*['"]was_paid_using_credit_card/, "'payment_info.was_paid_using_credit_card' available to Email" );
        like( $email_text, qr/TEST:\s*['"]was_paid_using_third_party/, "'payment_info.was_paid_using_third_party' available to Email" );
        like( $email_text, qr/TEST:\s*['"]payment_obj/, "'payment_info.payment_obj' available to Email" );

        $framework->flow_mech__customercare__cancel_order_email_submit;
        $framework->mech->has_feedback_success_ok( qr/Order Cancelled/, "SUCCESS Message Displayed" );
        _check_cancel_ok( $order );
    };

    return $framework;
}

=head2 _test_cancel_shipment_function

    _test_cancel_shipment_function( $framework, $ok_to_do_flag );

This tests the function '_cancel_shipment' in 'XTracker::Order::Actions::ChangeOrderStatus'
that will actually cancel the Shipment associated with the Order and also initiate the
request to the PSP to cancel any 'orders.payment' Pre-Auth's.

DEV NOTE: this should be in a unit test

=cut

sub _test_cancel_shipment_function {
    my ( $framework, $oktodo )  = @_;

    my $schema  = $framework->schema;
    my $dbh     = $framework->dbh;

    SKIP: {
        skip "_test_cancel_shipment_function", 1   if ( !$oktodo );

        note "TESTING '_cancel_shipment' function";

        $schema->txn_do( sub {
            my $handler = _init_mock_handler( $framework );

            note "test a Failed attempt at cancelling a Pre-Auth";
            my ( $order, $shipment, $payment )  = _create_an_order( 'card_debit' );
            Test::XTracker::Mock::PSP->cancel_action( 'FAIL-defined' );
            my @params  = _make_up_params( $handler, $order, $shipment );
            XTracker::Order::Actions::ChangeOrderStatus::_cancel_shipment( @params );
            cmp_ok( $payment->preauth_cancelled_failure, '==', 1, "Payment has a Pre-Auth Cancelled Failure" );
            like( $order->order_notes->first->note, qr/context 'Cancelling an Order'/,
                                            "Order Note has expected Context in it 'Cancelling an Order'" );
            cmp_ok( $order->order_notes->first->operator_id, '==', $handler->operator_id,
                                            "Order Note had correct Operator Id" );
            is( $xt_feedback->{type}, "INFO", "XT Feedback Type is 'INFO'" );
            like( $xt_feedback->{message}, qr/This Order has been Cancelled, However a problem has occured whilst attempting to cancel the Payment Card Authorisation, PLEASE notify Online Fraud of this Failure/, "First part of INFO Message as expected" );
            like( $xt_feedback->{message}, qr/Failure Reason: \(-1\) An Error Occured/, "Second part of INFO message looks good" );
            _check_cancel_ok( $shipment );

            note "test a Successful attempt at cancelling a Pre-Auth";
            ( $order, $shipment, $payment ) = _create_an_order( 'card_debit' );
            Test::XTracker::Mock::PSP->cancel_action( 'PASS' );
            @params  = _make_up_params( $handler, $order, $shipment );
            XTracker::Order::Actions::ChangeOrderStatus::_cancel_shipment( @params );
            cmp_ok( $payment->preauth_cancelled, '==', 1, "Payment Pre-Auth Has Been Cancelled" );
            is( $xt_feedback->{type}, "SUCCESS", "XT Feedback Type is 'SUCCESS'" );
            is( $xt_feedback->{message}, "Order & Payment Card Authorisation Cancelled", "SUCCESS Message as expected" );
            _check_cancel_ok( $shipment );

            note "and just to check Cancel an Order with no Payment Pre-Auth";
            note "test a Successful attempt at cancelling a Pre-Auth";
            ( $order, $shipment, $payment ) = _create_an_order( 'store_credit' );
            @params  = _make_up_params( $handler, $order, $shipment );
            XTracker::Order::Actions::ChangeOrderStatus::_cancel_shipment( @params );
            is( $xt_feedback->{type}, "SUCCESS", "XT Feedback Type is 'SUCCESS'" );
            is( $xt_feedback->{message}, "Order Cancelled", "SUCCESS Message as expected" );
            _check_cancel_ok( $shipment );

            # rollback any changes
            $schema->txn_rollback;
        } );
    };

    return $framework;
}

=head2 _cancel_a_pre_order_order

    _cancel_a_pre_order_order( $framework, $ok_to_do_flag );

Test Cancelling an Order that is linked to a Pre-Order.

=cut

sub _cancel_a_pre_order_order {
    my ( $framework, $oktodo )      = @_;

    my $schema  = $framework->schema;

    SKIP: {
        skip "_cancel_a_pre_order_order", 1         if ( !$oktodo );

        note "TESTING '_cancel_a_pre_order_order' function";

        my $order       = Test::XTracker::Data::PreOrder->create_order_linked_to_pre_order();
        my $pre_order   = $order->get_preorder;

        # 'set_department' should return the Operator Record of the user it's updating
        my $itgod_op    = Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                ]
            }
        } );

        # clean-up test data just in-case, before running tests
        $order->order_notes->delete;
        $order->payments->search_related('log_payment_preauth_cancellations')->delete;

        $framework->flow_mech__customercare__orderview( $order->id )
                    ->flow_mech__customercare__order_view_cancel_order
                        ->flow_mech__customercare__cancel_order_submit
        ;

        $framework->mech->log_snitch->pause;        # pause because of known error with connecting to the PSP
        $framework->flow_mech__customercare__cancel_order_email_submit;
        $framework->mech->log_snitch->unpause;

        $framework->mech->has_feedback_success_ok( qr/Order Cancelled/, "SUCCESS Message Displayed" );
        $framework->mech->has_feedback_info_ok( qr/Customer has NOT been Refunded.*should now go to Finance to Complete/i,
                                                        "Couldn't Refund INFO Message Displayed" );

        cmp_ok( $order->order_notes->count, '==', 0, "No Order Notes have been created" );
        cmp_ok( $order->payments->search_related('log_payment_preauth_cancellations')->count, '==', 0,
                                    "No attempt was made to CANCEL the Pre-Auth" );
        _check_cancel_ok( $order );
    };

    return $framework;
}

#-----------------------------------------------------------------

=head2 _check_cancel_ok

    _check_cancel_ok( $dbic_order_or_shipment );

Test Helper to make sure the order & shipment have been properly cancelled.

=cut

sub _check_cancel_ok {
    my ( $record )  = @_;

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
        cmp_ok( $order->order_status_id, '==', $ORDER_STATUS__CANCELLED, "Order Status Cancelled" );
    }

    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__CANCELLED, "Shipment Status Cancelled" );
    my @items   = $shipment->shipment_items->all;
    foreach my $item ( @items ) {
        cmp_ok( $item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__CANCELLED, "Shipment Item (".$item->id.") Status Cancelled" );
    }

    # check for Refund renumeration for Store Credit
    if ( $order->store_credit_tender ) {
        my $ship_value  = $shipment->shipping_charge
                          + $shipment->shipment_items->get_column('unit_price')->sum || 0
                          + $shipment->shipment_items->get_column('tax')->sum || 0
                          + $shipment->shipment_items->get_column('duty')->sum || 0;
        my $renum   = $shipment->refund_renumerations->first;
        ok( defined $renum, "Shipment has a Refund Invoice" );
        cmp_ok( $renum->renumeration_class_id, '==', $RENUMERATION_CLASS__CANCELLATION, "Refund Class is Cancellation" );
        cmp_ok( $renum->renumeration_type_id, '==', $RENUMERATION_TYPE__STORE_CREDIT, "Refund Type is Store Credit" );
        cmp_ok( $renum->store_credit, '==', $ship_value, "Refund Value is as expected: $ship_value" );
    }

    if ( $order->has_preorder ) {
        my $ship_value  = $shipment->shipping_charge
                          + $shipment->shipment_items->get_column('unit_price')->sum || 0
                          + $shipment->shipment_items->get_column('tax')->sum || 0
                          + $shipment->shipment_items->get_column('duty')->sum || 0;
        my $renum   = $shipment->refund_renumerations->first;
        ok( defined $renum, "Shipment has a Refund Invoice" );
        cmp_ok( $renum->renumeration_class_id, '==', $RENUMERATION_CLASS__CANCELLATION, "Refund Class is Cancellation" );
        cmp_ok( $renum->renumeration_type_id, '==', $RENUMERATION_TYPE__CARD_REFUND, "Refund Type is Card Refund" );
        cmp_ok( $renum->grand_total, '==', $ship_value, "Refund Value is as expected: $ship_value" );
        cmp_ok( $renum->store_credit, '==', 0, "Store Credit Value is ZERO" );
        cmp_ok( $renum->sent_to_psp, '==', 1, "'sent_to_psp' flag is TRUE" );
    }

    return;
}

=head2 _make_up_params

    _make_up_params( $handler, $dbic_order, $dbic_shipment );

Helper to make up the params use for the '_cancel_shipment' function.

=cut

sub _make_up_params {
    my ( $handler, $order, $shipment )  = @_;

    my @params;

    # first param is the $handler
    $params[0]  = $handler;

    # second param is the $data_ref
    $params[1]  = {
            order_id    => $order->id,
            order_info  => {
                    currency_id => $order->currency_id,
                },
            channel     => {
                    id  => $order->channel_id,
                },
            cancel_reason_id    => $CUSTOMER_ISSUE_TYPE__8__OTHER,
            send_email  => 'no',
            action  => 'Cancel',
            refund_type_id => ( $order->store_credit_tender ? 1 : 0 ),
        };

    # third param is the $shipment_ref
    $params[2]  = {
            id  => $shipment->id,
            shipment_status_id  => $shipment->shipment_status_id,
        };

    # fourth param is the $stock_manager
    $params[3]  = $order->channel->stock_manager;

    # fifth param is the $operator_id
    $params[4]  = $handler->operator_id;

    return @params;
}

=head2 _create_an_order

    $dbic_order = _create_an_order( $tender_type );

Helper to create an Order.

=cut

sub _create_an_order {
    my $tender_type     = shift;

    # create an Order
    my $orddetails  = $framework->flow_db__fulfilment__create_order(
        channel  => Test::XTracker::Data->channel_for_nap,
        products => 2,
        tenders => [ { type => $tender_type, value => 210 } ],
    );
    my $order       = $orddetails->{order_object};
    my $shipment    = $orddetails->{shipment_object};
    my $payment;

    note "Order Id/NR: ".$order->id."/".$order->order_nr;
    note "Shipment Id: ".$shipment->id;

    # create the 'orders.payment' record
    if ( $tender_type eq "card_debit" ) {
        my $next_preauth    = Test::XTracker::Data->get_next_preauth( $schema->storage->dbh );
        $payment    = Test::XTracker::Data->create_payment_for_order( $order, {
            psp_ref     => "TESTPSP$next_preauth",
            preauth_ref => $next_preauth,
        } );
        note "Order Payment Created, Id/Pre-Auth: ".$payment->id."/".$payment->preauth_ref;
    }

    return ( $order, $shipment, $payment );
}

=head2 _init_mock_handler

    $handler = _init_mock_handler( $framework, $args );

Helper to set-up a mock Handler.

=cut

sub _init_mock_handler {
    my ( $framework, $args )    = @_;

    my $schema  = $framework->schema;
    my $dbh     = $framework->dbh;

    $args->{schema} = $schema;
    $args->{dbh}    = $dbh;

    # set-up a Mock Handler;
    my $mock_handler    = Test::MockObject->new( $args );
    $mock_handler->set_isa('XTracker::Handler');
    $mock_handler->set_always( operator_id => $args->{operator_id} || $APPLICATION_OPERATOR_ID );
    $mock_handler->set_always( schema => $schema );
    $mock_handler->set_always( dbh => $dbh );

    return $mock_handler;
}

=head2 _xt_feedback

use as an override to 'XTracker::Error::xt_feedback'.

=cut

sub _xt_feedback {
    my ( $error_type, $error_message )  = @_;

    $xt_feedback->{type}    = $error_type;
    $xt_feedback->{message} = $error_message;

    return;
}


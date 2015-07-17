package Test::XTracker::Order::Actions::UpdateAddress;

use NAP::policy     qw( class test );

BEGIN {
    extends "NAP::Test::Class";
};

=head1 NAME

Test::XTracker::Order::Actions::UpdateAddress

=head1 DESCRIPTION

Tests the 'XTracker::Order::Actions::UpdateAddress' class. A mocked up
'XTracker::Handler' will be used to simulate a request being sent to the
handler.

Using a UNIT test to test this Handler as there is a need to check what
requests are made to the PSP.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Shipping;

use XTracker::Order::Actions::UpdateAddress     ();

use Test::XT::Data;

use Test::XTracker::Mock::WebServerLayer;
use Test::XTracker::Mock::LWP;

use XTracker::Constants::FromDB     qw( :shipping_charge_class :note_type );
use XTracker::Utilities             qw( format_currency_2dp );

use Mock::Quick;
use String::Random;


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    my $data = Test::XT::Data->new_with_traits( {
        traits => [ qw(
            Test::XT::Data::Order
            Test::XT::Data::Return
        ) ]
    } );
    $self->{data} = $data;
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->schema->txn_begin();

    my ( $channel, $pids ) = Test::XTracker::Data->grab_products( {
        how_many => 1,
    } );

    $self->{channel} = $channel;
    $self->{pids}    = $pids;
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->schema->txn_rollback();
}


=head1 TESTS

=head2 test_basket_update_when_shipping_charge_change_on_edit_shipment_address_page

For Orders paid using a Payment Method that requires the PSP to be notified of changes,
this tests that when using the '/.*/.*/UpdateAddress' Handler and doing something that
results in the Order Value being reduced, checks that the PSP is notified. In this Test's
case a new Shipping Charge is chosen for the Shipment.

Also in the case of Orders paid using Store Credit as well as a Payment that the Payment
is Cancelled and removed if the lower Order Value means that the Store Credit covers the
cost of the Order and therefore the Payment is no longer needed.

=cut

sub test_basket_update_when_shipping_charge_change_on_edit_shipment_address_page : Tests {
    my $self = shift;

    # mock the Designer Service because requests
    # using it will interfere with these tests
    my $mock_designer_service = qtakeover 'XT::Service::Designer' => (
        get_restricted_countries_by_designer_id => sub { return []; },
    );

    # end point on the PSP that should be used
    my $psp_update_basket_end_point  = Test::XTracker::Data->get_psp_end_point('Update Basket');
    my $psp_cancel_payment_end_point = Test::XTracker::Data->get_psp_end_point('Cancel Payment');
    # this will be called as well as the ones above
    my $psp_threshold_end_point      = Test::XTracker::Data->get_psp_end_point('Value Threshold Check');

    # get the general PSP Success Response
    my $psp_success_response = Test::XTracker::Data->get_general_psp_success_response( {
        reference => 'TEST',
    } );

    # should use the standard price defaults
    # of 100 per item + 10 shipping charge
    # with one product this should add up to 110
    # make the payment only cover part of the Shipping
    my $payment_amount      = 5;
    my $store_credit_amount = 105;

    # as we won't actually change the Address just the Charge, create a unique
    # Address that will always be found and so the Address Ids won't be different
    my $address = Test::XTracker::Data->create_order_address_in( 'current_dc', {
        address_line_2 => 'Addr 2 ' . String::Random->new( max => 15 )->randregex( '\w' x 10 ),
    } );

    my $order_data = $self->{data}->new_order(
        channel  => $self->{channel},
        products => $self->{pids},
        address  => $address,
        tenders  => [
            { type => 'card_debit',   value => $payment_amount },
            { type => 'store_credit', value => $store_credit_amount },
        ],
    );
    my $order          = $order_data->{order_object};
    my $shipment       = $order_data->{shipment_object};
    my @shipment_items = $shipment->shipment_items->all;

    # update Store Credit values
    $order->update( { store_credit => ( $store_credit_amount * -1 ) } );
    $shipment->update( { store_credit => ( $store_credit_amount * -1 ) } );

    # create some new Shipping Charges and then assign one to the Shipment
    my $shipping_charges = Test::XTracker::Data::Shipping->create_shipping_charges_for_shipment( $shipment, [ 10, 8, 7, 4 ] );
    $shipment->update( { shipping_charge_id => $shipping_charges->{ship_charge_10}{charge_record}->id } );

    # make sure a Payment has been created on the Order
    $order->payments->delete;
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    my $payment      = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );

    my $mock_lwp = Test::XTracker::Mock::LWP->new();
    $mock_lwp->enabled(1);


    note "Update Shipping Charge so there is still a need for a Payment - with Payment that doesn't require PSP to be updated";
    Test::XTracker::Data->change_payment_to_not_require_psp_notification_of_basket_changes( $payment );
    $mock_lwp->clear_all->add_response_OK( $psp_success_response );

    $self->_update_shipment_address_check_ok( $shipment, { new_charge => $shipping_charges->{ship_charge_8} } );
    cmp_ok( $mock_lwp->request_count, '==', 1, "only one request to the PSP made" );
    my $last_request = $mock_lwp->get_last_request;
    like( $last_request->as_string, qr/${psp_threshold_end_point}/, "and the request was to check the Threshold" );
    cmp_ok( $order->discard_changes->payments->count, '==', 1, "and the Payment is still attached to the Order" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_unlike( qr/payment.*removed/, "Payment Removed message is not in Success message" );


    note "Update Shipping Charge again so there is still a need for a Payment - with Payment that does require PSP to be updated";
    Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );
    $mock_lwp->clear_all
                # for the Basket Update request
                ->add_response_OK( $psp_success_response )
                # for the Threshold request
                ->add_response_OK( $psp_success_response )
    ;

    $self->_update_shipment_address_check_ok( $shipment, { new_charge => $shipping_charges->{ship_charge_7} } );
    cmp_ok( $mock_lwp->request_count, '==', 2, "two requests to the PSP made" );
    $last_request = $mock_lwp->get_next_request;
    like( $last_request->as_string, qr/${psp_update_basket_end_point}/, "the first request was to update the Basket" );
    $last_request = $mock_lwp->get_next_request;
    like( $last_request->as_string, qr/${psp_threshold_end_point}/, "the last request was to check the Threshold" );
    cmp_ok( $order->discard_changes->payments->count, '==', 1, "and the Payment is still attached to the Order" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_unlike( qr/payment.*removed/, "Payment Removed message is not in Success message" );


    note "Update Shipping Charge so that now Store Credit covers the Value of the Order";
    $mock_lwp->clear_all->add_response_OK( $psp_success_response );

    $self->_update_shipment_address_check_ok( $shipment, { new_charge => $shipping_charges->{ship_charge_4} } );
    cmp_ok( $mock_lwp->request_count, '==', 1, "one request made to the PSP made" );
    $last_request = $mock_lwp->get_last_request;
    like( $last_request->as_string, qr/${psp_cancel_payment_end_point}/, "and the request was to Cancel the Payment" );
    cmp_ok( $order->discard_changes->payments->count, '==', 0, "and the Payment has been Deleted from the Order" );
    Test::XTracker::Mock::WebServerLayer->check_success_message_like( qr/payment.*removed/, "Payment Removed message is in Success message" );


    # stop mocking LWP
    $mock_lwp->enabled(0);

    # stop mocking the Designer Service
    $mock_designer_service->restore('get_restricted_countries_by_designer_id');
    $mock_designer_service = undef;
}

=head2 test_cancel_payment_after_force_address_update

This will test the functionality where if the 'Force Update' option is used when Editing
an Address and the Payment Method has its 'cancel_payment_after_force_address_update' flag
that the Payment will be Cancelled and marked as Invalid.

=cut

sub test_cancel_payment_after_force_address_update : Tests() {
    my $self = shift;

    my %schema_calls = ();

    # mock the Designer Service because requests
    # using it will interfere with these tests
    my $mock_designer_service = qtakeover 'XT::Service::Designer' => (
        get_restricted_countries_by_designer_id => sub { return []; },
    );

    # end point on the PSP that should be used
    my $psp_cancel_payment_end_point  = Test::XTracker::Data->get_psp_end_point('Cancel Payment');
    my $psp_validate_addr_end_point   = Test::XTracker::Data->get_psp_end_point('Validate Address');
    my $psp_threshold_check_end_point = Test::XTracker::Data->get_psp_end_point('Value Threshold Check');

    # get the general PSP Success Response
    my $psp_success_response = Test::XTracker::Data->get_general_psp_success_response( {
        reference => 'TEST',
    } );

    # Create two known addresses and then flip between them in the tests
    my $address1 = Test::XTracker::Data->create_order_address_in( 'current_dc', {
        address_line_2 => 'Addr 2a ' . String::Random->new( max => 15 )->randregex( '\w' x 10 ),
    } );
    my $address2 = Test::XTracker::Data->create_order_address_in( 'current_dc', {
        address_line_2 => 'Addr 2b ' . String::Random->new( max => 15 )->randregex( '\w' x 10 ),
    } );

    # should use the standard price defaults
    # of 100 per item + 10 shipping charge
    # with one product this should add up to 110
    my $payment_amount = 110;

    my $order_data = $self->{data}->new_order(
        channel  => $self->{channel},
        products => $self->{pids},
        address  => $address1,
        tenders  => [
            { type => 'card_debit', value => $payment_amount },
        ],
    );
    my $order          = $order_data->{order_object};
    my $shipment       = $order_data->{shipment_object};
    my @shipment_items = $shipment->shipment_items->all;

    # create a known Shipping Charges and then assign one to the Shipment
    my $shipping_charges     = Test::XTracker::Data::Shipping->create_shipping_charges_for_shipment( $shipment, [ 10, 7 ] );
    my $shipping_charge      = $shipping_charges->{ship_charge_10};
    my $alt_shipping_charge  = $shipping_charges->{ship_charge_7};
    $shipment->update( { shipping_charge_id => $shipping_charge->{charge_record}->id } );

    # make sure a Payment has been created on the Order
    $order->payments->delete;
    my $payment_args = Test::XTracker::Data->get_new_psp_refs();
    my $payment      = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );

    # want Payment Method to want Basket Changes - such as Shipping Charges - sent to the PSP
    Test::XTracker::Data->change_payment_to_require_psp_notification_of_basket_changes( $payment );

    # create a query to search for an Order Note
    my $order_note_rs = $order->order_notes->search( {
        note_type_id => $NOTE_TYPE__FINANCE,
    } );

    # configure the Payment for the tests
    Test::XTracker::Data->allow_notifying_psp_of_address_change( $payment );
    Test::XTracker::Data->change_payment_to_not_require_psp_notification_of_basket_changes( $payment );

    my $mock_lwp = Test::XTracker::Mock::LWP->new();
    $mock_lwp->enabled(1);

    my %tests = (
        "Update Address and notify the PSP which doesn't return a failure" => {
            setup => {
                mock_lwp_responses => [
                    { add_response_OK => '' },  # Carrier Address Validation
                    { add_response_OK => $psp_success_response },
                ],
                setup_payment_method => '',
            },
            expect => {
                payment_valid_flag => 1,
                address_to_be_changed => 1,
                last_psp_request   => $psp_validate_addr_end_point,
                xt_message => {
                    message_type_to_check => 'check_success_message_like',
                    message_to_check_for  => qr/Shipment Address has been Updated/i,
                    test_label            => "Shipment Address updated Success message",
                },
            },
        },
        "Update Address and notify the PSP which returns a failure without using 'force' - but Payment Method doesn't want Payment to be Cancelled" => {
            setup => {
                mock_lwp_responses => [
                    { add_response_OK => '' },
                    { add_response    => $mock_lwp->response_INTERNAL_SERVER_ERROR() },
                ],
                setup_payment_method => 'change_payment_to_not_cancel_payment_after_force_address_update',
            },
            expect => {
                payment_valid_flag => 1,
                last_psp_request   => $psp_validate_addr_end_point,
                xt_message => {
                    message_type_to_check => 'check_warning_message_like',
                    message_to_check_for  => qr/Payment Provider.*rejected the Address Update/i,
                    test_label            => "Payment Provider rejected Address message",
                },
            },
        },
        "Update Address and notify the PSP which returns a failure without using 'force' - but Payment Method DOES want Payment to be Cancelled" => {
            setup => {
                mock_lwp_responses => [
                    { add_response_OK => '' },
                    { add_response    => $mock_lwp->response_INTERNAL_SERVER_ERROR() },
                ],
                setup_payment_method => 'change_payment_to_cancel_payment_after_force_address_update',
            },
            expect => {
                payment_valid_flag => 1,
                last_psp_request   => $psp_validate_addr_end_point,
                xt_message => {
                    message_type_to_check => 'check_warning_message_like',
                    message_to_check_for  => qr/
                        \QPayment Provider\E.*
                        \Qrejected the Address Update\E.*
                        \QPLEASE NOTE that the Payment will be Cancelled\E.*
                    /ix,
                    test_label => "Payment Provider rejected Address message with Cancel Warning",
                },
            },
        },
        "Update Address and notify the PSP which returns a failure using 'force' - but Payment Method doesn't want Payment to be Cancelled" => {
            setup => {
                mock_lwp_responses => [
                    { add_response_OK => '' },
                    { add_response    => $mock_lwp->response_INTERNAL_SERVER_ERROR() },
                ],
                setup_payment_method => 'change_payment_to_not_cancel_payment_after_force_address_update',
                with_force => 1,
            },
            expect => {
                payment_valid_flag => 1,
                last_psp_request   => $psp_validate_addr_end_point,
                address_to_be_changed => 1,
                xt_message => {
                    message_type_to_check => 'check_success_message_like',
                    message_to_check_for  => qr/Shipment Address has been Updated/i,
                    test_label            => "Address Update message shown",
                },
                order_notes => [
                    re( qr/
                        \Qdeemed the Change of Shipping Address Invalid\E.*
                        \Qnew Payment MUST be taken to Pay for the Order\E.*
                        \Qif the new Invalid Address is used\E.*
                    /ix ),
                ],
            },
        },
        "Update Address and notify the PSP which returns a failure using 'force' - but Payment Method DOES want Payment to be Cancelled" => {
            setup => {
                mock_lwp_responses => [
                    { add_response_OK => '' },
                    { add_response    => $mock_lwp->response_INTERNAL_SERVER_ERROR() },
                    { add_response_OK => $psp_success_response },       # Cancel Payment request
                ],
                setup_payment_method => 'change_payment_to_cancel_payment_after_force_address_update',
                with_force => 1,
            },
            expect => {
                payment_valid_flag => 0,
                last_psp_request   => $psp_cancel_payment_end_point,
                address_to_be_changed => 1,
                xt_message => {
                    message_type_to_check => 'check_success_message_like',
                    message_to_check_for  => qr/Payment has now been Cancelled and so a new Payment will be Required.*/i,
                    test_label => "Address Updated with with Cancel Payment Info message shown",
                },
                order_notes => [
                    re( qr/Cancel Payment Pre-Auth.*SUCCESSFUL/i ),
                    re( qr/
                        \Qdeemed the Change of Shipping Address Invalid\E.*
                        \Qnew Payment MUST be taken to Pay for the Order\E.*
                        \QPayment was Cancelled\E.*
                    /xi ),
                ],
            },
        },
        "Update Address & Shipping Charge and notify the PSP which returns a failure using 'force' - but Payment Method doesn't want Payment to be Cancelled" => {
            setup => {
                mock_lwp_responses => [
                    { add_response_OK => '' },
                    { add_response    => $mock_lwp->response_INTERNAL_SERVER_ERROR() },
                    { add_response_OK => $psp_success_response },       # Send Basket Update to the PSP
                    { add_response_OK => $psp_success_response },       # Order Value Threshold check to the PSP
                ],
                setup_payment_method => 'change_payment_to_not_cancel_payment_after_force_address_update',
                use_shipping_charge => $alt_shipping_charge,
                with_force => 1,
            },
            expect => {
                payment_valid_flag => 1,
                last_psp_request   => $psp_threshold_check_end_point,
                address_to_be_changed => 1,
                xt_message => {
                    message_type_to_check => 'check_success_message_like',
                    message_to_check_for  => qr/Shipment Address has been Updated/i,
                    test_label            => "Address Update message shown",
                },
                order_notes => [
                    re( qr/
                        \Qdeemed the Change of Shipping Address Invalid\E.*
                        \Qnew Payment MUST be taken to Pay for the Order\E.*
                        \Qif the new Invalid Address is used\E.*
                    /ix ),
                ],
            },
        },
        "Update Address & Shipping Charge and notify the PSP which returns a failure using 'force' - but Payment Method DOES want Payment to be Cancelled" => {
            setup => {
                mock_lwp_responses => [
                    { add_response_OK => '' },
                    { add_response    => $mock_lwp->response_INTERNAL_SERVER_ERROR() },
                    { add_response_OK => $psp_success_response },       # Cancel Payment request
                ],
                setup_payment_method => 'change_payment_to_cancel_payment_after_force_address_update',
                use_shipping_charge => $alt_shipping_charge,
                with_force => 1,
            },
            expect => {
                payment_valid_flag => 0,
                last_psp_request   => $psp_cancel_payment_end_point,
                address_to_be_changed => 1,
                xt_message => {
                    message_type_to_check => 'check_success_message_like',
                    message_to_check_for  => qr/Payment has now been Cancelled and so a new Payment will be Required.*/i,
                    test_label => "Address Updated with with Cancel Payment Info message shown",
                },
                order_notes => [
                    re( qr/Cancel Payment Pre-Auth.*SUCCESSFUL/i ),
                    re( qr/
                        \Qdeemed the Change of Shipping Address Invalid\E.*
                        \Qnew Payment MUST be taken to Pay for the Order\E.*
                        \QPayment was Cancelled\E.*
                    /xi ),
                ],
            },
        },
        "Update Address and notify the PSP which returns a failure using 'force' but Cancelling Payment FAILS also" => {
            setup => {
                mock_lwp_responses => [
                    { add_response_OK => '' },
                    { add_response    => $mock_lwp->response_INTERNAL_SERVER_ERROR() },             # Address Check
                    { add_response_OK => Test::XTracker::Data->get_general_psp_failure_response },  # Cancel Payment request
                ],
                setup_payment_method => 'change_payment_to_cancel_payment_after_force_address_update',
                with_force => 1,
            },
            expect => {
                payment_valid_flag => 1,
                last_psp_request   => $psp_cancel_payment_end_point,
                address_to_be_changed => 0,
                xt_message => {
                    message_type_to_check => 'check_warning_message_like',
                    message_to_check_for  => qr/rejected the Address.*Payment failed to be Cancelled/i,
                    test_label => "Address Updated with with failure to Cancel Payment message shown",
                },
                order_notes => [
                    re( qr/Cancel Payment Pre-Auth.*FAILED/i ),
                ],
            },
        },
        "Update Address and notify the PSP which doesn't return a failure using 'force' - and Payment Method doesn't want Payment to be Cancelled" => {
            setup => {
                mock_lwp_responses => [
                    { add_response_OK => '' },
                    { add_response_OK => $psp_success_response },
                ],
                setup_payment_method => 'change_payment_to_not_cancel_payment_after_force_address_update',
                with_force => 1,
            },
            expect => {
                payment_valid_flag => 1,
                last_psp_request   => $psp_validate_addr_end_point,
                address_to_be_changed => 1,
                xt_message => {
                    message_type_to_check => 'check_success_message_like',
                    message_to_check_for  => qr/Shipment Address has been Updated/i,
                    test_label            => "Shipment Address updated Success message",
                },
            },
        },
        "Update Address and notify the PSP which doesn't return a failure using 'force' - but Payment Method DOES want Payment to be Cancelled" => {
            setup => {
                mock_lwp_responses => [
                    { add_response_OK => '' },
                    { add_response_OK => $psp_success_response },
                ],
                setup_payment_method => 'change_payment_to_cancel_payment_after_force_address_update',
                with_force => 1,
            },
            expect => {
                payment_valid_flag => 1,
                last_psp_request   => $psp_validate_addr_end_point,
                address_to_be_changed => 1,
                xt_message => {
                    message_type_to_check => 'check_success_message_like',
                    message_to_check_for  => qr/Shipment Address has been Updated/i,
                    test_label            => "Shipment Address updated Success message",
                },
            },
        },
    );

    # mock methods on the 'DBIx::Class::Storage' otherwise
    # these tests will fail because of being in a nested transaction
    my $mock_schema = qtakeover 'DBIx::Class::Storage' => (
        txn_begin => sub {
                note "========> IN A MOCKED 'txn_begin' METHOD, MOCKED BY '" . __PACKAGE__ . "' <========";
                return 1;
            },
        txn_commit => sub {
                note "========> IN A MOCKED 'txn_commit' METHOD, MOCKED BY '" . __PACKAGE__ . "' <========";
                $schema_calls{commit} = 1;
                return 1;
            },
        txn_rollback => sub {
                note "========> IN A MOCKED 'txn_rollback' METHOD, MOCKED BY '" . __PACKAGE__ . "' <========";
                $schema_calls{rollback} = 1;
                return 1;
            },
    );

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};


        # reset the data
        $order_note_rs->reset->delete;
        $payment->discard_changes->update( {
            valid => 1,
        } );
        $payment->log_payment_preauth_cancellations->delete;
        $shipment->discard_changes->update( {
            shipment_address_id => $address1->id,
            shipping_charge_id  => $shipping_charge->{charge_record}->id,
        } );

        # set-up the Mock LWP Responses
        $mock_lwp->clear_all;
        foreach my $response ( @{ $setup->{mock_lwp_responses} } ) {
            my ( $method, $param ) = each %{ $response };
            $mock_lwp->$method( $param );
        }

        # now configure the Payment Method for the Payment
        if ( my $psp_method = $setup->{setup_payment_method} ) {
            Test::XTracker::Data->$psp_method( $payment );
        }

        # get rid of any calls made to the overridden methods,
        # do this just before we make the call to the Handler
        %schema_calls = ();

        # make the Request
        $self->_update_shipment_address_check_ok( $shipment, {
            new_charge  => $setup->{use_shipping_charge} // $shipping_charge,
            new_address => $address2,
            with_force  => $setup->{with_force} // 0,
        } );

        # check the last Response sent to the PSP
        my $last_request = $mock_lwp->get_last_request;
        my $expected_end_point = $expect->{last_psp_request};
        like( $last_request->as_string, qr/${expected_end_point}/,
                    "Last request to the PSP was for the Expected End-Point: '${expected_end_point}'" );

        # check whether the Address got Updated or not
        if ( $expect->{address_to_be_changed} ) {
            cmp_ok( $shipment->discard_changes->shipment_address_id, '==', $address2->id,
                                "the Shipping Address was changed" );
            ok( exists( $schema_calls{commit} ), "A Commit call was made" );
            ok( !exists( $schema_calls{rollback} ), "NO Rollback call was made" );
        }
        else {
            ok( exists( $schema_calls{rollback} ), "A Rollback call was made" );
        }

        # check the Payment's 'valid' flag
        cmp_ok( $payment->discard_changes->valid, '==', $expect->{payment_valid_flag},
                                "and Payment's 'valid' flag is as Expected" );

        if ( my $expect_order_notes = $expect->{order_notes} ) {
            my @got_notes = map { $_->note } $order_note_rs->reset->all;
            cmp_ok( scalar( @got_notes ), '==', scalar( @{ $expect_order_notes } ),
                                "the Expected number of Order Notes were Created" );
            cmp_deeply( \@got_notes, bag( @{ $expect_order_notes } ),
                                "and the Notes are as Expected" )
                        or diag "ERROR - Notes were not as Expected:\n"
                                . "Got: " . p( @got_notes ) . "\n"
                                . "Expected: " . p( $expect_order_notes );
        }
        else {
            cmp_ok( $order_note_rs->reset->count, '==', 0, "No Order Notes have been Created" );
        }

        # check the message shown to the Operator
        my $message_type_method = $expect->{xt_message}{message_type_to_check};
        Test::XTracker::Mock::WebServerLayer->$message_type_method(
            $expect->{xt_message}{message_to_check_for},
            $expect->{xt_message}{test_label},
        );
    }


    # stop mocking LWP
    $mock_lwp->enabled(0);

    # stop mocking the Schema
    $mock_schema->restore('txn_begin');
    $mock_schema->restore('txn_commit');
    $mock_schema->restore('txn_rollback');
    $mock_schema = undef;

    # stop mocking the Designer Service
    $mock_designer_service->restore('get_restricted_countries_by_designer_id');
    $mock_designer_service = undef;
}

#------------------------------------------------------------------------------

# helper that will Update the Address & check it worked
sub _update_shipment_address_check_ok {
    my ( $self, $shipment, $args ) = @_;

    my $new_charge  = $args->{new_charge};
    my $new_address = $args->{new_address};
    my $use_force   = $args->{with_force};

    my $new_charge_rec  = $new_charge->{charge_record};
    my $expected_charge = $new_charge->{gross_charge};
    my $original_charge = $shipment->shipping_charge;

    my $card_debit_tender    = $shipment->order->card_debit_tender;
    my $original_debit_value = $card_debit_tender->value;

    # if no new Address then keep the same Address
    my $address = $new_address // $shipment->shipment_address;

    # is there a shipping charge change
    my $updating_shipping_charge = (
        $shipment->shipping_charge_id != $new_charge_rec->id
        ? 1
        : 0
    );

    my $mock_web_layer = $self->_get_mock_web_layer_using_default_payload( {
        order_id                    => $shipment->order->id,
        shipment_id                 => $shipment->id,
        selected_shipping_charge_id => $new_charge_rec->id,
        shipping                    => $expected_charge,
        new_pricing                 => ( $updating_shipping_charge ? 1 : 0 ),
        force_update_address        => $use_force,
        # populate the Address params
        map { $_ => $address->$_ }
            qw(
                first_name
                last_name
                address_line_1
                address_line_2
                address_line_3
                towncity
                county
                postcode
                country
                urn
                last_modified
            ),
    } );

    # change the Shipping Address
    XTracker::Order::Actions::UpdateAddress::handler( $mock_web_layer );
    $shipment->discard_changes;

    if ( $updating_shipping_charge ) {
        is( format_currency_2dp( $shipment->shipping_charge ), format_currency_2dp( $expected_charge ),
                                "Shipping Charge Cost has been Updated on the Shipment" );
        cmp_ok( $shipment->shipping_charge_id, '==', $new_charge_rec->id, "and Shipping Charge Id has been Updated" );

        is(
            format_currency_2dp( $card_debit_tender->discard_changes->value ),
            format_currency_2dp( ( $original_debit_value - ( $original_charge - $expected_charge ) ) ),
            "Card Debit Tender has been adjusted correctly"
        );
    }

    return;
}

# helper to populate the GET Params of a Update Address
# request with common data that doesn't effect the tests
sub _get_mock_web_layer_using_default_payload {
    my ( $self, $args ) = @_;

    my %get_params = (
        address_type => 'Shipping',
        send_email   => 0,
        %{ $args },
    );

    return Test::XTracker::Mock::WebServerLayer->setup_mock_with_get_params(
        '/CustomerCare/OrderSearch/UpdateAddress',
        \%get_params,
    );
}


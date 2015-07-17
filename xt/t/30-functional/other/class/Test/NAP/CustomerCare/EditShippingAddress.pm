package Test::NAP::CustomerCare::EditShippingAddress;

use NAP::policy     qw( test );
use parent 'NAP::Test::Class';

=head1 NAME

Test::NAP::CustomerCare::EditShippingAddress - Test the 'Edit Shipping Address' option

=head1 DESCRIPTION

Test the 'Edit Shipping Address' option on the Left Hand Menu on the Order View page.

#TAGS orderview loops

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Invoice;
use Test::XT::Flow;

use XTracker::Utilities             qw( d2 );
use XTracker::Constants::Address    qw( :address_update_messages );
use XTracker::Constants::FromDB     qw(
                                        :authorisation_level
                                        :department
                                        :order_status
                                        :shipment_status
                                    );


sub startup : Test( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    $self->{framework}  = Test::XT::Flow->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
            'Test::XT::Flow::CustomerCare',
        ],
    } );

    $self->{operator}   = $self->rs('Public::Operator')->find( { username => 'it.god' } );
    $self->framework->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Customer Care/Customer Search',
                'Customer Care/Order Search',
            ],
        },
        dept => 'Customer Care',
    } );

    $self->{payment_methods} = Test::XTracker::Data->get_cc_and_third_party_payment_methods;
}

sub shutdown : Test( shutdown => no_plan ) {
    my $self    = shift;

    $self->SUPER::shutdown;
}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup;

    my $order_details = $self->framework->new_order(
        products => 3,
        channel  => Test::XTracker::Data->any_channel,
        tenders  => [ { type => 'card_debit', value => 605.00 } ],
    );
    $self->{order}    = $order_details->{order_object};
    $self->{shipment} = $order_details->{shipment_object};

    # sort out the cost of the Order, so
    # that the total amount paid is 605.00
    $self->{order}->update( { pre_auth_total_value => 605.00 } );
    $self->{shipment}->update( { shipping_charge => 20 } );
    $self->{shipment}->shipment_items->update( { # there are 3 of these
        unit_price => 150,
        tax        => 30,
        duty       => 15,
    } );
    $self->{total_paid} = 605.00;

    $self->{payment_args} = Test::XTracker::Data->get_new_psp_refs;
    delete $self->{payment_args}{settle_ref};

    # make sure the Operator is in the Customer Care department
    $self->{operator}->discard_changes->update( { department_id => $DEPARTMENT__CUSTOMER_CARE } );
}

sub teardown : Test( teardown => no_plan ) {
    my $self    = shift;

    $self->SUPER::teardown;
}


=head1 TESTS

=head2 test_edit_shipping_address_for_third_party_payment

Tests when an Order is paid using a Third Party Payment that requires the PSP to be
notified when there is a change in Shipping Address. Also checks that for Operators
in the Shipping Department updating the Address then it still goes into Credit Hold.

=cut

sub test_edit_shipping_address_for_third_party_payment : Tests {
    my $self = shift;

    my $order        = $self->{order};
    my $shipment     = $self->{shipment};

    # so as to avoid going over the Payment
    # Threshold just double the amount Paid
    $order->discard_changes->update( { pre_auth_total_value => ( $self->{total_paid} * 2 ) } );
    $order->tenders->update( { value => ( $self->{total_paid} * 2 ) } );


    # use a Third Party Payment Method which requires notifying
    # the PSP when there are any Shipping Address changes
    my $payment_method = $self->{payment_methods}{third_party}->discard_changes;
    my $orig_notify_psp_flag = $payment_method->notify_psp_of_address_change;
    $payment_method->update( { notify_psp_of_address_change => 1 } );
    $order->payments->delete;
    Test::XTracker::Data->create_payment_for_order( $order, {
        %{ $self->{payment_args} },
        payment_method => $payment_method,
    } );

    # get the Current Shipping Address
    my $ship_address = $shipment->discard_changes->shipment_address;

    my @tests = (
        {
            label            => "First Pass - No 'Force' option on final Confirmation Page",
            has_force_option => 0,
        },
        {
            label            => "Second Pass - 'Force' option on final Confirmation Page but don't use it",
            has_force_option => 1,
            use_force        => 0,
        },
        {
            label            => "Third Pass - Use 'Force' option on final Confirmation Page, Order Note should appear",
            has_force_option => 1,
            use_force        => 1,
            has_order_note   => 1,
            is_on_credit_hold=> 1,
        },
    );

    # Operator's in the Shipping Department don't get Orders put on Credit
    # Hold if the Address Changes, but that can't happen for PayPal payments
    my @departments = $self->rs('Public::Department')->search( {
        id => { 'IN' => [ $DEPARTMENT__CUSTOMER_CARE, $DEPARTMENT__SHIPPING ] },
    } )->all;

    foreach my $dept ( @departments ) {

        note "Testing with Department: '" . $dept->department . "'";
        $self->{operator}->discard_changes->update( { department_id => $dept->id } );

        # update Order & Shipment Statuses
        $order->discard_changes->update( {
            order_status_id => $ORDER_STATUS__ACCEPTED
        } );
        $shipment->discard_changes->update( {
            shipment_status_id  => $SHIPMENT_STATUS__PROCESSING,
            shipment_address_id => $ship_address->discard_changes->id,
        } );

        # get rid of any Order Notes
        $order->order_notes->delete;

        # update the current Shipping Address to a known state
        $ship_address->update( {
            address_line_1  => 'Addr Line 1',
            address_line_2  => 'Addr Line 2',
        } );

        # get to the Edit Address page
        $self->framework->flow_mech__customercare__orderview( $order->id )
                          ->flow_mech__customercare__edit_shipping_address
                            ->flow_mech__customercare__choose_address
        ;

        foreach my $test ( @tests ) {
            note "Testing: " . $test->{label};

            # change the Address & Confirm the Shipping Option
            $self->framework->flow_mech__customercare__edit_address( {
                    address_line_1  => $ship_address->address_line_2,
                    address_line_2  => $ship_address->address_line_1,
                } )
                    ->flow_mech__customercare__edit_address__confirm_shipping_option
            ;
            my $pg_data = $self->pg_data;
            if ( $test->{has_force_option} ) {
                ok( exists( $pg_data->{new_address}{'Force Save Address'} ), "Found 'Force' option on page" );
            }
            else {
                ok( !exists( $pg_data->{new_address}{'Force Save Address'} ), "Did NOT Find 'Force' option on page" );
            }

            if ( $test->{use_force} ) {
                # use the 'Force' option to save the Address
                $self->framework->flow_mech__customercare__confirm_address( {
                    force_update_address_checkbox => 1
                } );
            }
            else {
                # now confirm the Address Change and because the PSP can't be
                # contacted the Address Validation will therefore fail and
                # an appropriate Error Message should be shown
                $self->framework->catch_error(
                    qr/Address.*Invalid/i,
                    "Confirm Address should fail for PSP Address Validation reasons",
                    'flow_mech__customercare__confirm_address',
                );
            }

            $order->discard_changes;
            if ( $test->{has_order_note} ) {
                cmp_ok( $order->order_notes->count, '==', 1, "An Order was Created" );
                my $note = $order->order_notes->first;
                like( $note->note, qr/Address.*Invalid.*new Payment MUST be taken/i,
                                    "and the Note has the Invalid Address Warning" );
            }
            else {
                cmp_ok( $order->order_notes->count, '==', 0, "No Order Note Created" );
            }

            if ( $test->{is_on_credit_hold} ) {
                ok( $order->discard_changes->is_on_credit_hold, "Order is On Credit Hold" );
                ok( $shipment->discard_changes->is_on_finance_hold, "Shipment is On Finance Hold" );
            }
            else {
                ok( !$order->discard_changes->is_on_credit_hold, "Order is NOT On Credit Hold" );
                ok( !$shipment->discard_changes->is_on_finance_hold, "Shipment is NOT On Finance Hold" );
            }
        }
    }

    note "Now repeat, but this time with a Payment Method that doesn't need to notify the PSP";
    $payment_method->discard_changes->update( {
        notify_psp_of_address_change => 0,
    } );
    $order->discard_changes->order_notes->delete;
    $ship_address->discard_changes;

    $self->framework->flow_mech__customercare__orderview( $order->id )
                      ->flow_mech__customercare__edit_shipping_address
                        ->flow_mech__customercare__choose_address
                          ->flow_mech__customercare__edit_address( {
                                address_line_1  => $ship_address->address_line_1,
                                address_line_2  => $ship_address->address_line_2,
                          } )
                            ->flow_mech__customercare__edit_address__confirm_shipping_option
    ;
    my $pg_data = $self->pg_data;
    ok( !exists( $pg_data->{new_address}{'Force Save Address'} ), "Did NOT Find 'Force' option on page" );

    $self->framework->flow_mech__customercare__confirm_address;
    cmp_ok( $order->discard_changes->order_notes->count, '==', 0, "No Order Note Created" );



    # restore notify PSP flag on the Payment Method
    $payment_method->discard_changes->update( { notify_psp_of_address_change => $orig_notify_psp_flag } );
}

=head2 test_payment_method_that_requires_shipping_and_billing_address_be_the_same

Will test that when an Order has been paid using a Payment Method that requires
the Shipping Address to be the same as the Billing Address, that after editing the
Shipping Address the Billing Address will have also changed to use the same address.

=cut

sub test_payment_method_that_requires_shipping_and_billing_address_be_the_same : Tests {
    my $self = shift;

    my $order    = $self->{order};
    my $shipment = $self->{shipment};

    # create a Payment for the Order
    $order->payments->delete;
    my $payment = Test::XTracker::Data->create_payment_for_order( $order, $self->{payment_args} );

    # make sure the Payment Method requires the Shipping & Billing Addresses to be the same
    Test::XTracker::Data->require_payment_to_insist_shipping_and_billing_address_are_same( $payment );

    # create different known Addresses for Shipping & Billing and update the current ones
    my $ship_address = Test::XTracker::Data->create_order_address_in( 'current_dc', {
            address_line_2 => 'Shipping Address',
        } );
    my $bill_address = Test::XTracker::Data->create_order_address_in( 'current_dc', {
            address_line_2 => 'Billing Address',
        } );
    $shipment->discard_changes->update( { shipment_address_id => $ship_address->id } );
    $order->discard_changes->update( { invoice_address_id => $bill_address->id } );


    # expected Information Message that should be shown on each page when
    # editing the Shipping Address that the Billing Address will be updated too
    my $expect_info_message = qr/$ADDRESS_UPDATE_MESSAGE__BILLING_AND_SHIPPING_ADDRESS_SAME/i;

    $self->framework->flow_mech__customercare__orderview( $order->id );

    # Edit the Shipping Address, checking there is an information message
    # telling the Operator that the Billing Address will be updated too
    $self->framework
            ->test_for_info_message(
                    $expect_info_message,
                    "'Updating Billing Address' message shown on 'Choose Address' page",
                    flow_mech__customercare__edit_shipping_address => (),
                )
            ->test_for_info_message(
                    $expect_info_message,
                    "'Updating Billing Address' message shown on 'Edit Address' page",
                    flow_mech__customercare__choose_address => (),
                )
            ->test_for_info_message(
                    $expect_info_message,
                    "'Updating Billing Address' message shown on 'Confirm Shipping Option' page",
                    flow_mech__customercare__edit_address => ( {
                        address_line_2 => 'Shipping Address Change',
                    } ),
                )
            ->test_for_info_message(
                    $expect_info_message,
                    "'Updating Billing Address' message shown on 'Confirm Address' page",
                    flow_mech__customercare__edit_address__confirm_shipping_option => (),
                )
            ->test_for_status_message(
                    qr/Billing Address.*also.*Updated/i,
                    "'Billing Address also Updated' message shown when Shipping Address has been Updated",
                    flow_mech__customercare__confirm_address => (),
                )
    ;

    cmp_ok( $shipment->discard_changes->shipment_address_id, '!=', $ship_address->id,
                        "Shipping Address has been changed" );
    cmp_ok( $order->discard_changes->invoice_address_id, '!=', $bill_address->id,
                        "Billing Address has been changed" );
    cmp_ok( $order->invoice_address_id, '==', $shipment->shipment_address_id,
                        "Billing Address is the same as the Shipping Address" );

    my $got_log_count = $shipment->shipment_address_logs
                                    ->search( {
                                        changed_from => $ship_address->id,
                                        changed_to   => $shipment->shipment_address_id,
                                    } )->count();
    cmp_ok( $got_log_count, '==', 1, "a Shipping Address Log has been created for the Change" );
    $got_log_count = $order->order_address_logs
                            ->search( {
                                changed_from => $bill_address->id,
                                changed_to   => $order->invoice_address_id,
                            } )->count();
    cmp_ok( $got_log_count, '==', 1, "an Order Address Log has been created for the Change" );


    note "Change the Payment to NOT require Shipping & Billing Address to be the same";
    Test::XTracker::Data->change_payment_to_allow_shipping_and_billing_address_to_be_different( $payment );

    # replace the original addresses with the new ones
    $ship_address = $shipment->shipment_address;
    $bill_address = $order->invoice_address;

    $self->framework
            ->flow_mech__customercare__edit_shipping_address
            ->flow_mech__customercare__choose_address
            ->flow_mech__customercare__edit_address( {
                    address_line_2 => 'Another Shipping Address Change',
                } )
            ->flow_mech__customercare__edit_address__confirm_shipping_option
            ->test_for_status_message(
                    qr/Shipment Address has been Updated/i,
                    "'Shipping Address Updated' message shown",
                    flow_mech__customercare__confirm_address => (),
                )
    ;

    cmp_ok( $shipment->discard_changes->shipment_address_id, '!=', $ship_address->id,
                        "Shipping Address has been changed" );
    cmp_ok( $order->discard_changes->invoice_address_id, '==', $bill_address->id,
                        "Billing Address has NOT changed" );
    $got_log_count = $shipment->shipment_address_logs
                                ->search( {
                                    changed_from => $ship_address->id,
                                    changed_to   => $shipment->shipment_address_id,
                                } )->count();
    cmp_ok( $got_log_count, '==', 1, "a Shipping Address Log has been created for the Change" );


    # restore the Payment Method original state
    Test::XTracker::Data->psp_restore_all_original_states();
}


=head2 test_payment_method_allow_editing_of_shipping_address_post_settlement

Will test that when an Order has been paid using a Payment Method that Prevents
Editing of Shipping Address Correct Error is shown.

=cut

sub test_payment_method_allow_editing_of_shipping_address_post_settlement: Tests {
    my $self = shift;

    my $order    = $self->{order};
    my $shipment = $self->{shipment};

    # create a Payment for the Order
    $order->payments->delete;
    my $payment = Test::XTracker::Data->create_payment_for_order( $order, $self->{payment_args} );

    $payment->update({ fulfilled =>'t' });
    $self->{operator}->discard_changes->update( { department_id => $DEPARTMENT__SHIPPING_MANAGER } );

    # set 'allow_editing_of_shipping_address_after_settlement' = True,
    # implies editting shipping address is allowed
    Test::XTracker::Data->change_payment_to_allow_change_of_shipping_address_post_settlement( $payment );

    $self->framework->flow_mech__customercare__orderview( $order->id );
    $self->framework
            ->flow_mech__customercare__edit_shipping_address
            ->flow_mech__customercare__choose_address
            ->flow_mech__customercare__edit_address( {
                    address_line_2 => 'Another Shipping Address Change',
                } )
            ->flow_mech__customercare__edit_address__confirm_shipping_option
            ->flow_mech__customercare__confirm_address();



    # make sure the Payment Method sets 'allow_editing_of_shipping_address_after_settlement' = FALSE
    Test::XTracker::Data->change_payment_to_not_allow_change_of_shipping_address_post_settlement( $payment );

    $self->framework->flow_mech__customercare__orderview( $order->id );

    $self->framework
        ->catch_error(
            qr{This Order's Payment Method Does not allow change of Shipping Address once Order Payment has been Settled.},
            "Editing Shipping Address is prevented",
            flow_mech__customercare__edit_shipping_address => ()
        );

    # restore the Payment Method original state
    Test::XTracker::Data->psp_restore_all_original_states();

}

=head2 test_not_showing_unknown_country_when_editing_shipping_or_billing_address

Tests that the 'Unknown' Country isn't shown on the Edit Billing/Shipping Address
page in the Country drop-down list box.

Checking both Shipping and Billing Address here so as not to duplicate the logic but
other Billing Address tests should be done in 'Test::NAP::CustomerCare::EditBillingAddress'

=cut

sub test_not_showing_unknown_country_when_editing_shipping_or_billing_address : Tests() {
    my $self = shift;

    my $order    = $self->{order};
    my $shipment = $self->{shipment};

    foreach my $addr_type ( qw( Billing Shipping ) ) {

        note "TESTING when Editing a ${addr_type} Address";

        my $flow_edit_address_link = (
            $addr_type eq 'Billing'
            ? 'flow_mech__customercare__edit_billing_address'
            : 'flow_mech__customercare__edit_shipping_address'
        );


        note "Test when Creating a new Address";
        $self->framework->flow_mech__customercare__orderview( $order->id )
                            ->$flow_edit_address_link
                                ->flow_mech__customercare__new_address;
        $self->_check_for_unknown_country();

        # check that if '0' is submitted an error is thrown, ZERO is the value for the
        # dotted line '--------' which is the first option in the list of Countries
        $self->framework->catch_error(
            qr/Invalid Country/i,
            "'0' (ZERO) can't be submitted as a Country",
            flow_mech__customercare__edit_address => ( { country => '0' } ),
        );


        note "Test when Editing an Existing Address";
        $self->framework->flow_mech__customercare__orderview( $order->id )
                            ->$flow_edit_address_link
                                ->flow_mech__customercare__choose_address;
        $self->_check_for_unknown_country();
    }
}

#----------------------------------------------------------------------------------

# check out the Country Drop-Down to make
# sure the 'Unknown' country is not listed
sub _check_for_unknown_country {
    my $self = shift;

    my $pg_data   = $self->pg_data()->{address_form};

    my $countries = $pg_data->{Country}{select_values};
    cmp_ok( scalar( @{ $countries } ), '>', 3, "There are some Countries in the Drop-Down list" );

    my $unknown_count = scalar(
        grep { $_->[1] =~ m/^Unknown$/i  } @{ $countries }
    );
    cmp_ok( $unknown_count, '==', 0, "and the 'Unknown' Country is NOT in the list" );

    return;
}

sub framework {
    my $self    = shift;
    return $self->{framework};
}

sub mech {
    my $self    = shift;
    return $self->framework->mech;
}

sub pg_data {
    my $self    = shift;
    return $self->framework->mech->as_data;
}

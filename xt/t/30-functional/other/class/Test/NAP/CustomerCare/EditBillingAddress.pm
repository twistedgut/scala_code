package Test::NAP::CustomerCare::EditBillingAddress;

use NAP::policy     qw( test );
use parent 'NAP::Test::Class';

=head1 NAME

Test::NAP::CustomerCare::EditBillingAddress - Test the 'Edit Billing Address' option

=head1 DESCRIPTION

Test the 'Edit Billing Address' option on the Left Hand Menu on the Order View page.

#TAGS orderview loops

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Invoice;
use Test::XT::Flow;

use XTracker::Utilities             qw( d2 );
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
}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup;

    my $order_details   = $self->framework->new_order(
        products    => 3,
        channel     => Test::XTracker::Data->any_channel,
        tenders     => [ { type => 'card_debit', value => 605.00 } ],
    );
    my $order = $order_details->{order_object}->discard_changes;
    $self->{order}      = $order;
    $self->{shipment}   = $order_details->{shipment_object};

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
    delete $self->{payment_args}{settle_ref};       # should be pre-settle

    # make sure a Payment has been created for the Order
    $order->payments->delete;
    $self->{payment} = Test::XTracker::Data->create_payment_for_order( $order, $self->{payment_args} );

    # make sure the Operator is in the Customer Care department
    $self->{operator}->discard_changes->update( { department_id => $DEPARTMENT__CUSTOMER_CARE } );
}


=head1 TESTS

=head2 test_prevented_from_editing_billing_address_based_on_payment_method

Test that the Billing Address can't be Edited when a Payment Method has been used
to pay for the Order which doesn't allow it to be changed.

=cut

sub test_prevented_from_editing_billing_address_based_on_payment_method : Tests {
    my $self = shift;

    my $order   = $self->{order};
    my $payment = $self->{payment};

    # error message that is expected to be shown
    my $expect_err_msg = qr/Payment.*requires.*Billing and Shipping Address to be the same/i;

    # when the Payment doesn't allow for Editing the Billing Address
    # then an error message should be shown on the 'Choose Address' page
    Test::XTracker::Data->prevent_editing_of_billing_address_for_payment( $payment );
    $self->framework->flow_mech__customercare__orderview( $order->id );
    $self->framework->catch_error(
        $expect_err_msg,
        "Can't Edit Billing Address when Payment Method doesn't allow - on Choose Address page",
        flow_mech__customercare__edit_billing_address => (),
    );

    # now check the 'EditAddress' page also
    # prevents the Editing of the Billing Address
    Test::XTracker::Data->allow_editing_of_billing_address_for_payment( $payment );
    $self->framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__edit_billing_address;
    # got past Choose Address page, so now prevent editting again
    Test::XTracker::Data->prevent_editing_of_billing_address_for_payment( $payment );
    $self->framework->catch_error(
        $expect_err_msg,
        "Can't Edit Billing Address when Payment Method doesn't allow - on Edit Address page",
        flow_mech__customercare__choose_address => (),
    );


    # restore the flag on the Payment Method record
    Test::XTracker::Data->psp_restore_all_original_states();
}

=head2 test_prevented_from_editing_billing_address_when_payment_fulfilled

Test that when an Order's Payment has been Settled/Fulfilled that the Billing
Address can't be Edited.

=cut

sub test_prevented_from_editing_billing_address_when_payment_fulfilled : Tests {
    my $self = shift;

    my $order   = $self->{order};
    my $payment = $self->{payment};

    # make sure Payment Method allows Editting of Billing Address
    Test::XTracker::Data->allow_editing_of_billing_address_for_payment( $payment );

    # error message that is expected to be shown
    my $expect_err_msg = qr/too late to change.*Billing address/i;

    # when the Payment has been Fulfilled an error message
    # should be shown on the 'Choose Address' page
    $payment->update( { fulfilled => 1 } );
    $self->framework->flow_mech__customercare__orderview( $order->id );
    $self->framework->catch_error(
        $expect_err_msg,
        "Can't Edit Billing Address when Payment has been Fulfilled - on Choose Address page",
        flow_mech__customercare__edit_billing_address => (),
    );

    # now check the 'EditAddress' page also
    # prevents the Editing of the Billing Address
    $payment->update( { fulfilled => 0 } );
    $self->framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__edit_billing_address;
    # got past Choose Address page, so now flag as Fulfilled again
    $payment->update( { fulfilled => 1 } );
    $self->framework->catch_error(
        $expect_err_msg,
        "Can't Edit Billing Address when Payment Method has been Fulfilled - on Edit Address page",
        flow_mech__customercare__choose_address => (),
    );


    # restore the flag on the Payment Method record
    Test::XTracker::Data->psp_restore_all_original_states();
}

#----------------------------------------------------------------------------------

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

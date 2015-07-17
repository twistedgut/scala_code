package Test::NAP::CustomerCare::GratuityRefund;

use NAP::policy     qw( test );
use parent 'NAP::Test::Class';

=head1 NAME

Test::NAP::CustomerCare::GratuityRefund - Test the 'Create Credit/Debit' option

=head1 DESCRIPTION

Test the 'Create Credit/Debit' option on the Left Hand Menu on the Order View page.

#TAGS orderview shouldbecando loops finance

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Invoice;
use Test::XT::Flow;

use XTracker::Utilities             qw( d2 );
use XTracker::Constants             qw( :refund_error_messages );
use XTracker::Constants::FromDB     qw(
                                        :authorisation_level
                                        :department
                                        :renumeration_type
                                        :renumeration_class
                                        :renumeration_status
                                    );


sub startup : Test( startup => 1 ) {
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
    } );
}

sub shutdown : Test( shutdown ) {
    my $self    = shift;

    $self->SUPER::shutdown;
}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;

    $self->SUPER::setup;

    my $order_details   = $self->framework->dispatched_order(
        products    => 3,
        channel     => Test::XTracker::Data->any_channel,
        create_renumerations => 1,
    );
    $self->{order}      = $order_details->{order_object};
    $self->{shipment}   = $order_details->{shipment_object};
    my $shipment        = $self->{shipment};

    # specifiy some values to the Shipment & Shipment Items
    # so refunds can be generated against them
    $shipment->update( { shipping_charge => 25 } );
    my $renumeration    = $shipment->renumerations->first;
    $renumeration->update( { shipping => 25 } );
    my @ship_items      = $self->{shipment}->shipment_items->all;
    foreach my $ship_item ( @ship_items ) {
        $ship_item->update( {
            unit_price  => 100,
            tax         => 15,
            duty        => 20,
        } );
        $renumeration->create_related( 'renumeration_items', {
            shipment_item_id    => $ship_item->id,
            unit_price          => 100,
            tax                 => 15,
            duty                => 20,
        } );
    }

    # make sure the Operator is in the Finance Department
    $self->{operator}->discard_changes->update( { department_id => $DEPARTMENT__FINANCE } );
}

sub teardown : Test( teardown ) {
    my $self    = shift;

    $self->SUPER::teardown;

    # revert any changes made to Payment Methods done by the Tests
    Test::XTracker::Data->psp_restore_all_original_states();
}


=head1 TESTS

=head2 test_gratuity_refund_reasons_for_departments

Tests the Reasons shown when creating a Gratuity Refund are different for some Departments

=cut

sub test_gratuity_refund_reasons_for_departments : Tests {
    my $self    = shift;

    my $order           = $self->{order};
    my $operator        = $self->{operator};
    my @departments     = $self->rs('Public::Department')->all;
    my $reason_rs       = $self->rs('Public::RenumerationReason');
    my $disabled_reason = $reason_rs->first;
    my $old_status      = $disabled_reason->enabled;

    # Disable one of the reasons, to make sure it doesn't show up in the list.
    $disabled_reason->update({ enabled => 0 });

    # list the Departments that should be-able
    # to click on the 'Create Credit/Debit' link
    my %departments_can_create_invoice  = (
        $DEPARTMENT__CUSTOMER_CARE_MANAGER  => 1,
        $DEPARTMENT__SHIPPING_MANAGER       => 1,
        $DEPARTMENT__FINANCE                => 1,
    );

    DEPARTMENT:
    foreach my $department ( @departments ) {
        note "Testing for Department: '" . $department->department . "'";

        $operator->discard_changes->update( { department_id => $department->id } );

        $self->framework->flow_mech__customercare__orderview( $order->id );

        # check those Departments that should see the 'Create Credit/Debit' link
        my $link = $self->framework->mech->find_link( text => 'Create Credit/Debit' );
        if ( !exists( $departments_can_create_invoice{ $department->id } ) ) {
            ok( !defined $link, "Can't find 'Create Credit/Debit' link with Department" );
            next DEPARTMENT;
        }

        $self->framework->flow_mech__customercare_create_debit_credit;

        my @expect_reasons  = map { $_->reason }
                                    $reason_rs->get_compensation_reasons( $department )
                                                ->order_by_reason
                                                ->enabled_only
                                                ->all;
        my @got_reasons     = $self->_get_select_values_from_field(
            $self->pg_data->{invoice_details}{'Gratuity Reason'}
        );
        my $first_value     = shift @got_reasons;
        my $disabled_count  = grep { $_ eq $disabled_reason->reason } @got_reasons;
        like( $first_value, qr/select a reason/i, "First Reason is an Instruction" );
        is_deeply( \@got_reasons, \@expect_reasons, "Rest of the Reasons in Drop Down are as Expected" );
        cmp_ok( $disabled_count, '==', 0, 'The disabled reason is not present in the Reasons Drop Down' );
    }

    $disabled_reason->update({ enabled => $old_status });

}

=head2 test_create_gratuity_refund_with_reason

Tests Creating a Gratuity Refund and Specifying a Reason.

=cut

sub test_create_gratuity_refund_with_reason : Tests {
    my $self    = shift;

    my $order       = $self->{order};
    my $shipment    = $self->{shipment};
    my @ship_items  = $shipment->shipment_items->all;
    my $operator    = $self->{operator};

    my @reasons     = $self->rs('Public::RenumerationReason')
                            ->get_compensation_reasons( $operator->department_id );
    my $use_reason  = $reasons[0];

    # a Query to get the most Recent Renumeration
    my $renums_rs   = $shipment->renumerations->search( {}, {
        order_by    => 'id DESC',
    } );
    my $invoice     = $renums_rs->first;
    my $last_inv_id = ( $invoice ? $invoice->id : 0 );

    # work out what the Renumeration & Renumeration Item
    # values should be when the Renumeration gets created
    my %expect_invoice  = (
        invoice_nr              => '',
        renumeration_type_id    => $RENUMERATION_TYPE__CARD_REFUND,
        renumeration_class_id   => $RENUMERATION_CLASS__GRATUITY,
        renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
        shipping                => '11.340',
        misc_refund             => '15.450',
        alt_customer_nr         => 0,
        gift_credit             => '0.000',
        store_credit            => '0.000',
        currency_id             => $order->currency_id,
        gift_voucher            => '0.000',
        renumeration_reason_id  => $use_reason->id,
    );
    my %expect_items    = map {
        $ship_items[ $_ ]->id   => {
            unit_price  => ( 1 + ( $_ * 1 ) + .01 ),
            tax         => ( 1 + ( $_ * 1 ) + .02 ),
            duty        => ( 1 + ( $_ * 1 ) + .03 ),
        },
    } 0..$#ship_items;


    $self->framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare_create_debit_credit;

    # try without specifying a Reason
    $self->framework->errors_are_fatal(0);
    $self->framework->flow_mech__customercare___refundForm_submit( {
        invoice_reason  => '',
        misc_refund     => $expect_invoice{misc_refund},
    } );
    $self->mech->has_feedback_error_ok(
        qr/Specify a Reason/i,
        "Got Error Message when trying to Create an Invoice without a Reason"
    );
    $self->framework->errors_are_fatal(1);

    # no with a Reason, using 'd2' around values to make it realistic of what people type in
    $self->framework->flow_mech__customercare___refundForm_submit( {
        type_id         => $expect_invoice{renumeration_type_id},
        invoice_reason  => $expect_invoice{renumeration_reason_id},
        (
            map {
                'unit_price_' . $_  => d2( $expect_items{ $_ }->{unit_price} ),
                'tax_' . $_         => d2( $expect_items{ $_ }->{tax} ),
                'duty_' . $_        => d2( $expect_items{ $_ }->{duty} ),
            } keys %expect_items
        ),
        shipping        => d2( $expect_invoice{shipping} ),
        misc_refund     => d2( $expect_invoice{misc_refund} ),
    } );
    ok( exists( $self->pg_data->{invoice_details}{'Gratuity Reason'} ),
            "Gratuity Reason found on Confirm page" );
    is_deeply(
        $self->pg_data->{invoice_details}{'Gratuity Reason'},
        {
            input_name  => "invoice_reason_id",
            input_value => $use_reason->id,
            value       => $use_reason->reason,
        },
        "and Reason Shown is as Expected: '" . $use_reason->reason . "'"
    );

    # Confirm the Creation of the Invoice
    $self->framework->flow_mech__customercare__refundForm_confirm_submit;
    $invoice    = $renums_rs->reset->first;
    cmp_ok( $invoice->id, '>', $last_inv_id, "after Confirming a new Invoice was Created" );
    cmp_deeply( { $invoice->get_columns }, superhashof( \%expect_invoice ),
                "and the Invoice has all Expected Data" );

    my @logs    = $invoice->renumeration_status_logs->all;
    cmp_ok( @logs, '==', 1, "and the Invoice has 1 Status Log" );
    cmp_ok( $logs[0]->renumeration_status_id, '==', $RENUMERATION_STATUS__AWAITING_ACTION,
                "and the Log is for the Correct Status: 'Awaiting Action'" );
    cmp_ok( $logs[0]->operator_id, '==', $self->{operator}->id,
                "and Logged against the correct user" );

    my @invoice_items   = $invoice->renumeration_items->all;
    cmp_ok( scalar( @invoice_items ), '==', scalar( keys %expect_items ),
                "expected number of Invoice Items have been created" );
    is_deeply( {
            map {
                $_->shipment_item_id => {
                    unit_price  => d2( $_->unit_price ),
                    tax         => d2( $_->tax ),
                    duty        => d2( $_->duty ),
                }
            } @invoice_items
        },
        \%expect_items,
        "and the Invoice Items All have the Expected Values"
    );

    ok( exists( $self->pg_data->{invoice_details}{'Gratuity Reason'} ),
                "Gratuity Reason found on View page" );
    is( $self->pg_data->{invoice_details}{'Gratuity Reason'}, $use_reason->reason,
                "and Reason Shown is as Expected: '" . $use_reason->reason . "'" );
}

=head2 test_invoices_on_order_view_page

Tests that Invoices/Renumerations show up correctly on the Order View page.

=cut

sub test_invoices_on_order_view_page : Tests {
    my $self    = shift;

    my $order       = $self->{order};
    my $shipment    = $self->{shipment};
    my $operator    = $self->{operator};

    my @reasons     = $self->rs('Public::RenumerationReason')
                            ->get_compensation_reasons( $operator->department_id );
    my $use_reason  = $reasons[0];

    my %tests   = (
        'Order Class Invoice'   => {
            class_id        => $RENUMERATION_CLASS__ORDER,
            use_invoice     => $shipment->renumerations->first,     # use the Renumeration created with the Order
            expect_reason   => 'Order',
            reason_label_on_view_page => 'Reason',
        },
        'Cancellation Class Invoice'   => {
            class_id        => $RENUMERATION_CLASS__CANCELLATION,
            expect_reason   => 'Cancellation',
            reason_label_on_view_page => 'Reason',
        },
        'Return Class Invoice'   => {
            class_id        => $RENUMERATION_CLASS__RETURN,
            expect_reason   => 'Return',
            reason_label_on_view_page => 'Reason',
        },
        'Gratuity Class Invoice with Reason'   => {
            class_id        => $RENUMERATION_CLASS__GRATUITY,
            use_reason_id   => $use_reason->id,
            reason_enabled  => 1,
            expect_reason   => $use_reason->reason,
            reason_label_on_view_page => 'Gratuity Reason',
        },
        'Gratuity Class Invoice with DISABLED Reason'   => {
            class_id        => $RENUMERATION_CLASS__GRATUITY,
            use_reason_id   => $use_reason->id,
            reason_enabled  => 0,
            expect_reason   => $use_reason->reason . ' (Disabled)',
            reason_label_on_view_page => 'Gratuity Reason',
        },
        'Gratuity Class Invoice without Reason just like an Old Gratuity record' => {
            class_id        => $RENUMERATION_CLASS__GRATUITY,
            expect_reason   => 'Gratuity',
            reason_label_on_view_page => 'Gratuity Reason',
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: '${label}'";
        my $test    = $tests{ $label };
        my $invoice = $test->{use_invoice} //
                        Test::XTracker::Data::Invoice->create_invoice( {
                            shipment    => $shipment,
                            class_id    => $test->{class_id},
                            reason_id   => $test->{use_reason_id},
                        } );

        # Update the "enabled" status of the reason.
        my $old_status  = $use_reason->enabled;
        $use_reason->update({ enabled => $test->{reason_enabled} // 1 });

        note "check what is shown on the Order View page";
        $self->framework->flow_mech__customercare__orderview( $order->id );

        my $invoice_row = $self->_get_invoice_row_from_page( $invoice );
        ok( defined $invoice_row, "Found Row for Invoice in 'Payments & Refunds' section" );
        is( $invoice_row->{Reason}, $test->{expect_reason},
                "Reason shown on the page is as Expected: '$test->{expect_reason}'" );

        note "check what is shown on the Invoice View page";
        $self->framework->flow__customercare__click_on_invoice_to_view( $invoice->id );

        my $field_label = $test->{reason_label_on_view_page};
        my $details     = $self->pg_data->{invoice_details};
        ok( exists( $details->{ $field_label } ),
                "Reason Field's Label as Expected: '${field_label}'" );
        is( $details->{ $field_label }, $test->{expect_reason},
                "and Reason shown is as Expected: '$test->{expect_reason}'" );

        # Restore the "enabled" status of the reason.
        $use_reason->update({ enabled => $old_status });

    }

}

=head2 test_restrictions_on_goodwill_card_refunds

Tests the use of the 'allow_goodwill_refund_using_payment' flag on the 'orders.payment_method'
table and that it Restricts the ability to use pure Goodwill Refund for Payment Methods which
have that flag set to FALSE for both Creating and Editing Invoices.

This method just specifies the Test Cases to use and then calls two private methods to actually
run the tests for Creating and Editing Invoices.

=cut

sub test_restrictions_on_goodwill_card_refunds : Tests {
    my $self = shift;

    # get all the Renumeration Types so as not to need
    # to use long constant names in the test definitions
    my %renum_types = map {
        $_->type => $_,
    } $self->rs('Public::RenumerationType')->all;

    my %tests = (
        "Specifying Goodwill Refund amount for Card Refund when Payment Method doesn't allow Goodwill Refunds to Card" => {
            setup => {
                allow_goodwill_card_refunds => 0,
                params => {
                    type_id     => $renum_types{'Card Refund'}->id,
                    misc_refund => 5,
                },
            },
            expect => {
                error_message_thrown => 1,
            },
        },
        "Specifying Goodwill Refund amount for Store Credit when Payment Method doesn't allow Goodwill Refunds to Card" => {
            setup => {
                allow_goodwill_card_refunds => 0,
                params => {
                    type_id     => $renum_types{'Store Credit'}->id,
                    misc_refund => 5,
                },
            },
            expect => {
                error_message_thrown => 0,
            },
        },
        "Specifying Goodwill Refund amount for Card Refund when Payment Method does allow Goodwill Refunds to Card" => {
            setup => {
                allow_goodwill_card_refunds => 1,
                params => {
                    type_id     => $renum_types{'Card Refund'}->id,
                    misc_refund => 5,
                },
            },
            expect => {
                error_message_thrown => 0,
            },
        },
        "Specifying Goodwill Refund amount for Store Credit when Payment Method does allow Goodwill Refunds to Card" => {
            setup => {
                allow_goodwill_card_refunds => 1,
                params => {
                    type_id     => $renum_types{'Store Credit'}->id,
                    misc_refund => 5,
                },
            },
            expect => {
                error_message_thrown => 0,
            },
        },
        "Specifying other Refund amount for Card Refund when Payment Method doesn't allow Goodwill Refunds to Card" => {
            setup => {
                allow_goodwill_card_refunds => 0,
                params => {
                    type_id  => $renum_types{'Card Refund'}->id,
                    shipping => 5,
                },
            },
            expect => {
                error_message_thrown => 1,
            },
        },
        "Specifying other Refund amount & Goodwill Refund for Card Refund when Payment Method doesn't allow Goodwill Refunds to Card" => {
            setup => {
                allow_goodwill_card_refunds => 0,
                params => {
                    type_id     => $renum_types{'Card Refund'}->id,
                    shipping    => 5,
                    misc_refund => 5,
                },
            },
            expect => {
                error_message_thrown => 1,
            },
        },
        "Specifying other Refund amount & Goodwill Refund for Store Credit when Payment Method doesn't allow Goodwill Refunds to Card" => {
            setup => {
                allow_goodwill_card_refunds => 0,
                params => {
                    type_id     => $renum_types{'Store Credit'}->id,
                    shipping    => 5,
                    misc_refund => 5,
                },
            },
            expect => {
                error_message_thrown => 0,
            },
        },
        "Specifying other Refund amount & Goodwill Refund for Card Refund when Payment Method does allow Goodwill Refunds to Card" => {
            setup => {
                allow_goodwill_card_refunds => 1,
                params => {
                    type_id     => $renum_types{'Card Refund'}->id,
                    shipping    => 5,
                    misc_refund => 5,
                },
            },
            expect => {
                error_message_thrown => 0,
            },
        },
        "Specifying other Refund amount & Negative Goodwill Refund for Card Refund when Payment Method doesn't allow Goodwill Refunds to Card" => {
            setup => {
                allow_goodwill_card_refunds => 0,
                params => {
                    type_id     => $renum_types{'Card Refund'}->id,
                    shipping    => 5,
                    misc_refund => -5,
                },
            },
            expect => {
                error_message_thrown => 1,
            },
        },
        "Specifying a Goodwill Refund for a Card Refund for an Order which was paid using only Store Credit (so no 'payment' record)" => {
            setup => {
                no_payment => 1,
                params => {
                    type_id     => $renum_types{'Card Refund'}->id,
                    misc_refund => 5,
                },
            },
            expect => {
                error_message_thrown => 0,
            },
        },
    );

    # run the above tests through the following contexts
    $self->_test_restriction_of_creating_goodwill_card_refund( \%tests );
    $self->_test_restriction_of_editing_goodwill_refunds( \%tests );
}

=head2 _test_restriction_of_creating_goodwill_card_refund

Called by the Test Method 'test_restrictions_on_goodwill_card_refunds' this is a private
method that runs tests in the Context of Creating an Invoice.

=cut

sub _test_restriction_of_creating_goodwill_card_refund {
    my ( $self, $tests ) = @_;

    note "TEST CONTEXT: Testing Restrictions on Goodwill Refunds when Creating Invoices";

    my $order = $self->{order};

    # used to create a Payment for the Order
    my $psp_refs = Test::XTracker::Data->get_new_psp_refs();

    # just get one Refund Reason to use for all tests
    my $refund_reason = $self->rs('Public::RenumerationReason')->first;

    foreach my $label ( keys %{ $tests } ) {
        note "TESTING: ${label}";
        my $test   = $tests->{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        my $expected_error_message;

        # Remove any Payment on the Order
        $order->discard_changes->payments->delete;

        # create a Payment for the Order and configure the Payment Method as specified
        unless ( $setup->{no_payment} ) {
            my $payment = Test::XTracker::Data->create_payment_for_order( $order, $psp_refs );
            if ( $setup->{allow_goodwill_card_refunds} ) {
                Test::XTracker::Data->change_payment_to_allow_goodwill_refund_to_payment( $payment );
            }
            else {
                Test::XTracker::Data->change_payment_to_not_allow_goodwill_refund_to_payment( $payment );
            }

            # Error Message expected when not allowed to do Goodwill Refunds
            $expected_error_message = sprintf( $GOODWILL_REFUND_AGAINST_CARD_ERR_MSG, $payment->payment_method->payment_method );
        }

        $self->framework->flow_mech__customercare__orderview( $order->id )
                            ->flow_mech__customercare_create_debit_credit;

        # make up the params for the FORM submit
        my %params = (
            invoice_reason => $refund_reason->id,
            %{ $setup->{params} },
        );

        if ( $expect->{error_message_thrown} ) {
            $self->framework->catch_error(
                qr/\Q${expected_error_message}\E/i,
                "Got Goodwill Refund Error Message",
                flow_mech__customercare___refundForm_submit => ( \%params ),
            );
        }
        else {
            # should be-able to submit form without an error being thrown
            $self->framework->flow_mech__customercare___refundForm_submit( \%params );
        }
    }
}

=head2 _test_restriction_of_editing_goodwill_refunds

Called by the Test Method 'test_restrictions_on_goodwill_card_refunds' this is a private
method that runs tests in the Context of Editing an Invoice.

=cut

sub _test_restriction_of_editing_goodwill_refunds {
    my ( $self, $tests ) = @_;

    note "TEST CONTEXT: Testing Restrictions on Goodwill Refunds when Editing Invoices";

    my $order    = $self->{order};
    my $shipment = $self->{shipment};

    # used to create a Payment for the Order
    my $psp_refs = Test::XTracker::Data->get_new_psp_refs();

    # create a Refund Invoice for a 'Return' as 'Gratuity'
    # refunds can't have their Renumeration Type changed
    my $renumeration = $shipment->create_related( 'renumerations', {
        invoice_nr             => '',
        renumeration_type_id   => $RENUMERATION_TYPE__CARD_REFUND,
        renumeration_class_id  => $RENUMERATION_CLASS__RETURN,
        renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION,
        shipping               => 1,
        misc_refund            => 0,
        alt_customer_nr        => 0,
        gift_credit            => '0.000',
        store_credit           => '0.000',
        currency_id            => $order->currency_id,
        gift_voucher           => '0.000',
    } );

    foreach my $label ( keys %{ $tests } ) {
        note "TESTING: ${label}";
        my $test   = $tests->{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        my $expected_error_message;

        # reset Invoice
        $renumeration->discard_changes->update( {
            renumeration_type_id   => $RENUMERATION_TYPE__CARD_REFUND,
            shipping               => 1,
            misc_refund            => 0,
        } );

        # Remove any Payment on the Order
        $order->discard_changes->payments->delete;

        # create a Payment for the Order and configure the Payment Method as specified
        unless ( $setup->{no_payment} ) {
            my $payment = Test::XTracker::Data->create_payment_for_order( $order, $psp_refs );
            if ( $setup->{allow_goodwill_card_refunds} ) {
                Test::XTracker::Data->change_payment_to_allow_goodwill_refund_to_payment( $payment );
            }
            else {
                Test::XTracker::Data->change_payment_to_not_allow_goodwill_refund_to_payment( $payment );
            }

            # Error Message expected when not allowed to do Goodwill Refunds
            $expected_error_message = sprintf( $GOODWILL_REFUND_AGAINST_CARD_ERR_MSG, $payment->payment_method->payment_method );
        }

        $self->framework->flow_mech__customercare__orderview( $order->id )
                            ->flow__customercare__click_on_invoice_to_edit( $renumeration->id );

        if ( $expect->{error_message_thrown} ) {
            $self->framework->catch_error(
                qr/\Q${expected_error_message}\E/i,
                "Got Goodwill Refund Error Message",
                flow_mech__customercare___refundForm_submit => ( $setup->{params} ),
            );
        }
        else {
            # should be-able to submit form without an error being thrown
            $self->framework->test_for_status_message(
                qr/Invoice updated successfully/i,
                "Invoice got updated",
                flow_mech__customercare___refundForm_submit => ( $setup->{params} ),
            );
        }
    }
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

sub _get_select_values_from_field {
    my ( $self, $field )    = @_;

    my @values  = map { $_->[1] }
                        @{ $field->{select_values} };
    return @values;
}

sub _get_invoice_row_from_page {
    my ( $self, $invoice )  = @_;

    my $value   = d2( $invoice->discard_changes->grand_total );

    my $payments_on_page = $self->pg_data->{meta_data}
                                    ->{payments_and_refunds};

    my ( $row ) = grep {
        $_->{Value} =~ m/\s\Q${value}\E/
    } @{ $payments_on_page };

    return $row;
}


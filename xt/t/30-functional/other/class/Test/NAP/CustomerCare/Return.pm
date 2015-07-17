package Test::NAP::CustomerCare::Return;

use NAP::policy 'tt', 'test';
use parent 'NAP::Test::Class';

=head1 NAME

Test::NAP::CustomerCare::Return - Test the Returns Process

=head1 DESCRIPTION

Test the Returns Process, so far covers:

    * Creating a Return with a Third Party Payment
    * Check whether Items can be Selected for Return
      based on their Returnable State Id field

#TAGS rma

=cut

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB     qw(
                                        :authorisation_level
                                        :customer_issue_type
                                        :department
                                        :renumeration_type
                                        :shipment_item_returnable_state
                                    );


sub startup : Test( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    $self->{payment_method} = Test::XTracker::Data->get_cc_and_third_party_payment_methods;

    # get return reason
    my $reason = $self->schema->resultset('Public::CustomerIssueType')->find(
        $CUSTOMER_ISSUE_TYPE__7__FABRIC
    );
    $self->{return_reason} = $reason;

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
        dept  => 'Customer Care',
    } );
}

sub shut_down : Test( shutdown => no_plan ) {
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
        tenders     => [ { type => 'card_debit', value => 1500 } ],
    );
    $self->{order}      = $order_details->{order_object};
    $self->{shipment}   = $order_details->{shipment_object};

    my $psp_refs = Test::XTracker::Data->get_new_psp_refs();
    $self->{payment}    = Test::XTracker::Data->create_payment_for_order( $self->{order}, $psp_refs );
}

sub teardown : Test( teardown => no_plan ) {
    my $self    = shift;

    $self->SUPER::teardown;
}


=head1 TESTS

=head2 test_return_with_third_party_payment

Tests that when a Third Party or Credit Card is used to Pay for the Order
that the correct description appears on the Create RMA pages which means
'PayPal' should be shown instead of Credit Card if that was how the
Order was paid for.

=cut

sub test_return_with_third_party_payment : Tests {
    my $self    = shift;

    my $order       = $self->{order};
    my $shipment    = $self->{shipment};
    my $payment     = $self->{payment};

    my $credit_card_payment = $self->{payment_method}{credit_card};
    my $third_party_payment = $self->{payment_method}{third_party};

    my @products_to_return  = map {
        {
            sku           => $_->get_true_variant->sku,
            selected      => 1,
            return_reason => $self->{return_reason}->description,
        }
    } $shipment->shipment_items->all;

    my %tests = (
        "Paid using a Credit Card" => {
            setup => {
                payment_method => $credit_card_payment,
            },
            expect => {
                paid_for    => 'Card Debit',
                refund_type => 'Card Refund',
            },
        },
        "Paid using a Third Party Payment" => {
            setup => {
                payment_method => $third_party_payment,
            },
            expect => {
                paid_for    => $third_party_payment->payment_method,
                refund_type => $third_party_payment->payment_method . ' Account',
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };
        my $setup   = $test->{setup};
        my $expect  = $test->{expect};

        $payment->discard_changes->update( {
            payment_method_id => $setup->{payment_method}->id,
        } );

        # get to the select products to return page
        $self->framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__view_returns
                        ->flow_mech__customercare__view_returns_create_return;

        my $pg_data = $self->pg_data->{returns_create};
        like( $pg_data->{paid_for}, qr/$expect->{paid_for}/i,
                        "'Order was Paid For' is as Expected" );
        like( $pg_data->{refund_type}{value}, qr/$expect->{refund_type}/i,
                        "one of the 'Refund Types' available is as Expected" );

        # make and test a request to the helper that
        # returns a preview of what the refund will be,
        # this is used on the first Create Return page
        $self->framework->open_tab('AJAX');
        $self->framework->turn_note_success_status_off;

        $self->framework->flow_mech__ajax__customercare__preview_refund_split( $shipment->id, {
            products => \@products_to_return,
        } );
        my $response = $self->pg_data();
        like( $response->[0]{renumeration_type}, qr/$expect->{refund_type}/i,
                "Refund Type in response from Preview Refund Split helper as Expected" );

        $self->framework->turn_note_success_status_on;
        $self->framework->close_tab('AJAX');

        # then select products and go to the confirmation page
        $self->framework->flow_mech__customercare__view_returns_create_return_data( {
            products => \@products_to_return,
        } );

        $pg_data = $self->pg_data->{returns_create};
        like( $pg_data->{refunds}{refund_type}{value}, qr/$expect->{refund_type}/i,
                        "'Refund Type' for Refund is as Expected" );
    }
}

=head2 test_refunds_given_to_store_credit_or_payment_method_only

On the Create Returns page an option to have Store Credit only Refund is shown
and for Customer Care Managers an option to give a Full Card Refund is shown.

This method tests the conditions when those options should be shown based on
the Order's Payment Method.

=cut

sub test_refunds_given_to_store_credit_or_payment_method_only : Tests {
    my $self = shift;

    my $order       = $self->{order};
    my $shipment    = $self->{shipment};
    my $payment     = $self->{payment};

    my $operator    = $self->{operator};

    my @products_to_return  = map {
        {
            sku           => $_->get_true_variant->sku,
            selected      => 1,
            return_reason => $self->{return_reason}->description,
        }
    } $shipment->shipment_items->all;

    # list of expected refund types
    # that should appear on the page
    my %refund_types = (
        card_refund      => $RENUMERATION_TYPE__CARD_REFUND,
        store_credit     => $RENUMERATION_TYPE__STORE_CREDIT,
        no_refund        => 0,
        full_card_refund => 99,
    );

    my %tests = (
        "Payment Method used DOESN'T allow Store Credit only Refunds" => {
            setup => {
                call_method_to_change_payment => 'prevent_payment_from_allowing_store_credit_only_refunds',
            },
            expect => {
                refund_types => [ $refund_types{card_refund}, $refund_types{no_refund} ],
            },
        },
        "Payment Method used DOES allow Store Credit only Refunds" => {
            setup => {
                call_method_to_change_payment => 'change_payment_to_allow_store_credit_only_refunds',
            },
            expect => {
                refund_types => [ $refund_types{card_refund}, $refund_types{store_credit}, $refund_types{no_refund} ],
            },
        },
        "Part Pay with Store Credit and a Payment Method that DOESN'T allow Store Credit only Refunds" => {
            setup => {
                part_payment => 1,
                call_method_to_change_payment => 'prevent_payment_from_allowing_store_credit_only_refunds',
            },
            expect => {
                refund_types => [ $refund_types{card_refund}, $refund_types{no_refund} ],
            },
        },
        "Part Pay with Store Credit and a Payment Method that DOES allow Store Credit only Refunds" => {
            setup => {
                part_payment => 1,
                call_method_to_change_payment => 'change_payment_to_allow_store_credit_only_refunds',
            },
            expect => {
                refund_types => [ $refund_types{card_refund}, $refund_types{store_credit}, $refund_types{no_refund} ],
            },
        },
        "Operator's Department is 'Customer Care Manager' and Payment Method allows Payment & Store Credit Only Refunds" => {
            setup => {
                department   => $DEPARTMENT__CUSTOMER_CARE_MANAGER,
                part_payment => 1,
                call_method_to_change_payment => [ qw(
                        change_payment_to_allow_store_credit_only_refunds
                        change_payment_to_allow_payment_only_refunds
                    ) ],
            },
            expect => {
                refund_types => [ $refund_types{card_refund}, $refund_types{store_credit}, $refund_types{no_refund}, $refund_types{full_card_refund} ],
            },
        },
        "Operator's Department is 'Customer Care Manager' and Payment Method DOESN'T allow Payment & Store Credit Only Refunds" => {
            setup => {
                department   => $DEPARTMENT__CUSTOMER_CARE_MANAGER,
                part_payment => 1,
                call_method_to_change_payment => [ qw(
                        prevent_payment_from_allowing_store_credit_only_refunds
                        prevent_payment_from_allowing_payment_only_refunds
                    ) ]
            },
            expect => {
                refund_types => [ $refund_types{card_refund}, $refund_types{no_refund} ],
            },
        },
        "Operator's Department is NOT 'Customer Care Manager' and Payment Method allows Payment & Store Credit Only Refunds" => {
            setup => {
                department   => $DEPARTMENT__CUSTOMER_CARE,
                part_payment => 1,
                call_method_to_change_payment => [ qw(
                        change_payment_to_allow_store_credit_only_refunds
                        change_payment_to_allow_payment_only_refunds
                    ) ],
            },
            expect => {
                refund_types => [ $refund_types{card_refund}, $refund_types{store_credit}, $refund_types{no_refund} ],
            },
        },
        "Opeator is NOT 'Customer Care Manager' & Order Paid Using only Store Credit" => {
            setup => {
                department => $DEPARTMENT__CUSTOMER_CARE,
                no_payment => 1,
            },
            expect => {
                refund_types => [ $refund_types{store_credit}, $refund_types{no_refund} ],
            },
        },
        "Opeator is 'Customer Care Manager' & Order Paid Using only Store Credit" => {
            setup => {
                department => $DEPARTMENT__CUSTOMER_CARE_MANAGER,
                no_payment => 1,
            },
            expect => {
                refund_types => [ $refund_types{store_credit}, $refund_types{no_refund}, $refund_types{full_card_refund} ],
            },
        },
    );

    # will get more information than usual when parsing the page
    $self->mech->client_parse_cell_deeply( 1 );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        # always set the Operator to be 'Customer Care', then override if requested to
        $operator->discard_changes->update( { department_id => $DEPARTMENT__CUSTOMER_CARE } );
        $operator->update( { department_id => $setup->{department} } )      if ( $setup->{department} );

        # tender types that will be required
        # to be created for the Order
        my @tender_types;

        push @tender_types, 'Store Credit'
                        if ( $setup->{part_payment} || $setup->{no_payment} );
        push @tender_types, 'Payment'
                        unless ( $setup->{no_payment} );

        my $payment = $self->_create_payment_and_tenders( $order, @tender_types );

        if ( my $methods_to_call = $setup->{call_method_to_change_payment} ) {
            # change the Payment Method to how the test wants it
            $methods_to_call = [ $methods_to_call ]     if ( ref( $methods_to_call ) ne 'ARRAY' );
            foreach my $method_name ( @{ $methods_to_call } ) {
                Test::XTracker::Data->$method_name( $payment );
            }
        }

        # get to the select products to return page
        $self->framework->flow_mech__customercare__orderview( $order->id )
                        ->flow_mech__customercare__view_returns
                        ->flow_mech__customercare__view_returns_create_return;

        my $pg_data = $self->pg_data->{returns_create};
        my @got_refund_types = map {
            $_->{input_value}
        } @{ $pg_data->{refund_type}{inputs} };

        cmp_deeply( \@got_refund_types, bag( @{ $expect->{refund_types} } ),
                        "the Expected Refund Options were shown on the page" )
                            or diag "ERROR - did not get Expected Refund Options:\n" .
                                    "Got: " . p( @got_refund_types ) . "\n" .
                                    "Expected: " . p( $expect->{refund_types} );
    }


    # other tests won't want more info when parsing
    $self->mech->client_parse_cell_deeply( 0 );

    # restore the state of the Payment Method
    Test::XTracker::Data->psp_restore_all_original_states();
}

=head2 test_item_select_with_returnable_state_id

Test that when the 'returnable_state_id' is set to the different states that
you can or can't select an item on the first Create Return page accordingly.

=cut

sub test_item_select_with_returnable_state_id : Tests() {
    my $self = shift;

    my $order    = $self->{order};
    my $shipment = $self->{shipment};

    my @items = $shipment->discard_changes->shipment_items->all();
    # update the three Items each with a different State Id
    $items[0]->update( { returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__YES } );
    $items[1]->update( { returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__NO } );
    $items[2]->update( { returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__CC_ONLY } );

    # get to the select products to return page
    $self->framework->flow_mech__customercare__orderview( $order->id )
                    ->flow_mech__customercare__view_returns
                    ->flow_mech__customercare__view_returns_create_return;

    # check each Item to make sure it can/can't be returned

    my $got = $self->_get_item_line_for_sku_on_select_items_page( $items[0]->get_sku );
    is( $got->{'Select'}{input_name}, 'selected-' . $items[0]->id,
                        "Shipment Item with Returnable State of 'Yes' CAN be Selected" );

    $got = $self->_get_item_line_for_sku_on_select_items_page( $items[1]->get_sku );
    like( $got->{'Select'}, qr/can't be Returned/i,
                        "Shipment Item with Returnable State of 'NO' CAN'T be Selected" );

    $got = $self->_get_item_line_for_sku_on_select_items_page( $items[2]->get_sku );
    is( $got->{'Select'}{input_name}, 'selected-' . $items[2]->id,
                        "Shipment Item with Returnable State of 'CC ONLY' CAN be Selected" );


    # clean-up the Test Data by making sure all Items are Returnable
    $shipment->discard_changes->shipment_items->update( {
        returnable_state_id => $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
    } );
}

#----------------------------------------------------------------------------------

# helper to create an 'orders.payment' record
# and 'orders.tender' records for an Order
sub _create_payment_and_tenders {
    my ( $self, $order, @types ) = @_;

    my $total_value = $order->get_total_value;
    my $num_tenders = scalar( @types );

    my $total_per_tender = $total_value / $num_tenders;

    my $rank = 0;

    # delete existing Payment & Tenders
    $order->discard_changes->payments->delete;
    $order->tenders->delete;

    # return this to the caller
    my $payment;

    foreach my $tender_type ( @types ) {

        $rank++;

        my $tender_args = {
            rank  => $rank,
            value => $total_per_tender,
        };

        if ( $tender_type eq 'Payment' ) {
            # regardless of Payment Method it will be 'Card Debit'
            $tender_args->{type_id} = $RENUMERATION_TYPE__CARD_DEBIT;

            # now create an 'orders.payment' record
            my $payment_args = Test::XTracker::Data->get_new_psp_refs();
            $payment = Test::XTracker::Data->create_payment_for_order( $order, $payment_args );
        }

        if ( $tender_type eq 'Store Credit' ) {
            $tender_args->{type_id} = $RENUMERATION_TYPE__STORE_CREDIT;
        }

        $order->create_related( 'tenders', $tender_args );
    }

    return $payment;
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

# helper to return the Line Item for a SKU
# on the Create Return Select Items page
sub _get_item_line_for_sku_on_select_items_page {
    my ( $self, $sku ) = @_;

    my $rows = $self->pg_data()->{returns_items};

    my $retval = {};
    # Line Items on the Create Return Select Items page
    # take up 2 rows each so just check every other row
    for ( my $i = 0; $i < @{ $rows }; $i = $i + 2 ) {
        if ( $rows->[ $i ]{'Product'} eq $sku ) {
            $retval = $rows->[ $i ];
            # only the 'Product' key has anything in it in the second row
            $retval->{product_description} = $rows->[ ( $i + 1 ) ]{'Product'};
            last;
        }
    }

    return $retval;
}


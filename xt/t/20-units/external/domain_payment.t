#!/usr/bin/env perl

use NAP::policy "tt", 'test', 'class';

BEGIN {
    extends "NAP::Test::Class";
};

use Test::XTracker::Data;
use XTracker::Constants::Payment qw( :psp_return_codes );
use XT::Domain::Payment;
use Data::UUID;
use JSON;

=head1 DESCRIPTION

=cut


sub _startup : Test( startup => 1) {
    my $self = shift;

    use_ok 'Test::XT::Domain::Payment::Mock';

    $self->{domain} = Test::XT::Domain::Payment::Mock->new;
    $self->{card_no} = '5573470000000001';
    $self->{cvs} = '547';
}

sub _setup : Test( setup => no_plan ) {
    my $self = shift;

    # clear the mocked Requests & Responses before each test
    $self->{domain}->mock_lwp->clear_requests;
    $self->{domain}->mock_lwp->clear_responses;
}

sub test_init : Tests {
    my $self = shift;

    $self->domain->set_return_code_reason( 'Test Reason' );

    my $result = $self->ps_init;

    isa_ok( $result, 'HASH', 'The result of init_with_payment_session' );

    cmp_deeply( $result, {
        returnCodeResult  => $self->domain->return_code,
        reference         => $self->domain->reference,
        returnCodeReason  => $self->domain->return_code_reason,
        provider          => $self->domain->psp_provider,
        extraReason       => $self->domain->psp_extra_reason,
        acsUrl            => $self->domain->psp_acs_url,
        pareq             => $self->domain->psp_pareq,
    } );

}

sub test_preauth : Tests {
    my $self = shift;

    my $init_ref = $self->ps_init( 1 );

    $self->domain->set_return_code( $PSP_RETURN_CODE__SUCCESS );
    $self->domain->set_return_code_reason( 'Success' );
    $self->domain->set_psp_extra_reason( 'ACCEPTED' );

    my $preauth = $self->ps_preauth( $init_ref );

    isa_ok( $preauth, 'HASH', 'The result of preauth_with_payment_session' );

    cmp_deeply( $preauth, {
        returnCodeResult => $self->domain->return_code,
        reference        => $self->domain->reference,
        returnCodeReason => $self->domain->return_code_reason,
        extraReason      => $self->domain->psp_extra_reason,
        provider         => $self->domain->psp_provider,
        authCode         => $self->domain->psp_auth_code,
        cv2AvsStatus     => $self->domain->cv2avs_status,
    }, 'preauth_with_payment_session returns the correct data' );

    my $failed_preauth = $self->ps_preauth( );

    cmp_deeply( $failed_preauth, {
        'extraReason'      => 'Historical transaction reference is required',
        'provider'         => undef,
        'reference'        => undef,
        'returnCodeReason' => 'The request contains missing and/or incorrect data',
        'returnCodeResult' => $PSP_RETURN_CODE__MISSING_INFO
    }, 'preauth_with_payment_session returns the correct data for a missing reference' );

}

sub test_settle : Tests {
    my $self = shift;

    my $init_ref = $self->ps_init( 1 );
    my $preauth
      = $self->ps_preauth( $init_ref );

    $self->domain->set_return_code( $PSP_RETURN_CODE__SUCCESS );
    $self->domain->set_return_code_reason( "Success" );
    $self->domain->set_psp_extra_reason( "FULFILLED OK" );

    my $settle_ok
      = $self->ps_settle($preauth->{reference});

    cmp_deeply( $settle_ok, {
        SettleResponse => {
            reference        => $self->domain->reference,
            returnCodeResult => $self->domain->return_code,
            returnCodeReason => $self->domain->return_code_reason,
            extraReason      => $self->domain->psp_extra_reason,
            provider         => $self->domain->psp_provider
        }
    }, 'settle_payment returns the correct data' );

    my $settle_fail = $self->ps_settle();

    cmp_deeply( $settle_fail, {
       'SettleResponse' => {
            'extraReason'      => 'Historical transaction reference is required',
            'provider'         => undef,
            'reference'        => undef,
            'returnCodeReason' => 'The request contains missing and/or incorrect data',
            'returnCodeResult' => $PSP_RETURN_CODE__MISSING_INFO,
        }
    }, 'settle_payment returns the correct data for a missing reference' );

}

sub test_refund : Tests {
    my $self = shift;

    my $init_ref = $self->ps_init();
    my $preauth
      = $self->ps_preauth($init_ref, $self->{card_no}, $self->{cvs});
    my $settlement
      = $self->ps_settle($preauth->{reference});

    $self->domain->set_return_code( $PSP_RETURN_CODE__SUCCESS );
    $self->domain->set_return_code_reason( "Success" );
    $self->domain->set_psp_extra_reason( "ACCEPTED" );

    my $success_response = {
        RefundResponse => {
            reference        => $self->domain->reference,
            returnCodeResult => $self->domain->return_code,
            returnCodeReason => $self->domain->return_code_reason,
            extraReason      => $self->domain->psp_extra_reason,
            provider         => $self->domain->psp_provider
        }
    };

    my $failure_response = {
       'RefundResponse' => {
            'extraReason'      => 'Historical transaction reference is required',
            'provider'         => undef,
            'reference'        => undef,
            'returnCodeReason' => 'The request contains missing and/or incorrect data',
            'returnCodeResult' => $PSP_RETURN_CODE__MISSING_INFO,
        }
    };

    my $settle_reference    = $settlement->{SettleResponse}->{reference};
    my $refund_items        = [ { sku => 'SKU', name => 'NAME', amount => 1234, vat => 56 } ];
    my %basic_payload       = ( %{ $self->card_details( qw( coinAmount channel ) ) }, reference => $settle_reference );
    my %refund_item_payload = ( refundItems => $refund_items );

    my %tests = (
        'Success with a reference' => {
            setup => {
                ps_refund_arguments => [ $settle_reference ],
            },
            expected_response => $success_response,
        },
        'Failure with no reference' => {
            setup => {
                ps_refund_arguments => [],
            },
            expected_response => $failure_response,
        },
        'Dies when refundItems is not an ArrayRef' => {
            setup => {
                ps_refund_arguments => [ $settle_reference, \'Not an ArrayRef' ],
            },
            expected_response => qr/Parameter "refundItems" passed to refund_payment is not an ArrayRef/,
        },
        'refundItems is not present when the list is empty' => {
            setup => {
                ps_refund_arguments => [ $settle_reference, [] ],
            },
            expected_response   => $success_response,
            expected_payload    => { %basic_payload },

        },
        'refundItems is present when the list is not empty' => {
            setup => {
                ps_refund_arguments => [ $settle_reference, $refund_items ],
            },
            expected_response   => $success_response,
            expected_payload    => { %basic_payload, %refund_item_payload },

        },
    );

    while ( my ( $name, $test ) = each %tests ) {
        subtest $name => sub {

            my @ps_refund_arguments = @{ $test->{setup}->{ps_refund_arguments} };
            my $expected_response   = $test->{expected_response};
            my $expected_payload    = $test->{expected_payload};

            $self->{domain}->mock_lwp->clear_requests;
            $self->{domain}->mock_lwp->clear_responses;

            if ( ref( $expected_response ) eq 'Regexp' ) {

                throws_ok( sub { $self->ps_refund( @ps_refund_arguments ) },
                    $expected_response, "refund_payment dies with the correct error: $expected_response" );

            } else {

                cmp_deeply( $self->ps_refund( @ps_refund_arguments ),
                    $expected_response, 'refund_payment returns the correct data' );

            }

            if ( $expected_payload ) {

                my $payload = JSON->new->utf8->decode(
                    $self->{domain}->mock_lwp->get_last_request->content );

                cmp_deeply( $payload, $expected_payload,
                    'The response is as expected' );

            }

        }
    }

}

sub test_cancel_preauth : Tests {
    my $self = shift;

    my $init_ref = $self->ps_init ( 1 );
    my $preauth = $self->ps_preauth( $init_ref );

    cmp_ok($preauth->{returnCodeResult}, '==', 1,
       'Preauth successful' );

    my $preauth_ref = $preauth->{reference};

    $self->domain->set_return_code( $PSP_RETURN_CODE__SUCCESS );
    $self->domain->set_return_code_reason( "Success" );
    $self->domain->set_psp_extra_reason( "CANCELLED OK" );

    my $cancel
      = $self->domain->cancel_preauth(
                             { preAuthReference => $preauth_ref });

    cmp_deeply( $cancel, {
        CancelResponse => {
            reference        => $self->domain->reference,
            returnCodeResult => $self->domain->return_code,
            returnCodeReason => $self->domain->return_code_reason,
            extraReason      => $self->domain->psp_extra_reason,
            provider         => $self->domain->psp_provider,
        },
    }, 'cancel_preauth returns the correct data for a missing reference' );

    my $cancel_fail
      = $self->domain->cancel_preauth(
                             { preAuthReference => undef});

    cmp_deeply( $cancel_fail, {
       'CancelResponse' => {
            'extraReason'      => 'Historical transaction reference is required',
            'provider'         => undef,
            'reference'        => undef,
            'returnCodeReason' => 'The request contains missing and/or incorrect data',
            'returnCodeResult' => $PSP_RETURN_CODE__MISSING_INFO,
        }
    }, 'cancel_preauth returns the correct data for a missing reference' );

}

sub test_getinfo_payment : Tests {
    my $self = shift;

    my $init_ref = $self->ps_init( 1 );
    my $preauth = $self->ps_preauth( $init_ref );
    my $preauth_ref = $preauth->{reference};

    $self->domain->set_card_first_digit( '6' );
    $self->domain->set_card_last_four_digits( '6667' );
    $self->domain->set_card_type( 'DisasterCard' );
    $self->domain->set_coin_amount( 123456 );
    $self->domain->set_cv2avs_status( 'ALL MATCH');
    $self->domain->set_reference( 'CARROT');

    my $payment
      = $self->domain->getinfo_payment({ reference => $preauth_ref });

    isa_ok( $payment, 'HASH', 'Result of getinfo_payment' );

    cmp_deeply( $payment, {
        paymentMethod               => 'CREDITCARD',
        address1                    => $self->domain->address_1,
        address2                    => $self->domain->address_2,
        address3                    => $self->domain->address_3,
        address4                    => $self->domain->address_4,
        authCode                    => $self->domain->psp_auth_code,
        billingCountry              => $self->domain->billing_country,
        cardInfo                    => {
            cardExpiryMonth             => $self->domain->card_expiry_date->strftime( '%m' ),
            cardExpiryYear              => $self->domain->card_expiry_date->strftime( '%y' ),
            cardNumberFirstDigit        => $self->domain->card_first_digit,
            cardNumberLastFourDigits    => $self->domain->card_last_four_digits,
            cardType                    => $self->domain->card_type,
            newCard                     => $self->domain->is_new_card,
        },
        coinAmount                  => $self->domain->coin_amount,
        currency                    => $self->domain->currency,
        cv2avsStatus                => $self->domain->cv2avs_status,
        email                       => $self->domain->email_address,
        firstName                   => $self->domain->first_name,
        lastName                    => $self->domain->last_name,
        postcode                    => $self->domain->postcode,
        preauthReference            => $self->domain->preauth_internal_reference,
        provider                    => $self->domain->psp_provider,
        providerReference           => $self->domain->reference,
        threeDSecureResponse        => $self->domain->secure_response_3d,
        title                       => $self->domain->title,
        paymentHistory              => [
            cardInfo                => {
                cardNumberFirstDigit        => $self->domain->card_first_digit,
                cardNumberLastFourDigits    => $self->domain->card_last_four_digits,
                storedCard                  => $self->domain->card_history_is_stored_card,
            },
            currency                        => $self->domain->currency,
            cv2avsStatus                    => $self->domain->cv2avs_status,
            date                            => $self->domain->card_history_date->strftime( '%c' ),
            orderNumber                     => $self->domain->card_history_order_number,
            preAuthInternalReason           => $self->domain->card_history_preauth_internal_reason,
            preAuthProviderReason           => $self->domain->card_history_preauth_provider_reason,
            preAuthProviderReturnCode       => $self->domain->card_history_preauth_provider_return_code,
            preAuthReference                => $self->domain->reference,
            success                         => $self->domain->card_history_sucess,
            settlement                      => [
                settleReference      => $self->domain->reference,
                settlementCoinAmount => $self->domain->coin_amount,
                settlementReason     => $self->domain->card_history_settlement_reason ,
                success              => $self->domain->card_history_settlement_success,
            ],
        ],
    }, 'getinfo_payment returns the correct data for a valid reference' );

    my $failed_payment
      = $self->domain->getinfo_payment({ reference => undef });

    isa_ok( $failed_payment, 'HASH', 'Result of getinfo_payment' );

    cmp_deeply( $failed_payment, {}, 'getinfo_payment returns the correct data for an invalid reference' );

}

sub test_getorder_numbers : Tests {
    my $self = shift;

    # We test two valid and one invalid reference.
    my $order_nrs
      = $self->domain->getorder_numbers(
          { initialReferences => { string => [qw/ 1-1 2-2 3 /] }});

    isa_ok( $order_nrs, 'HASH', 'The result of getorder_numbers' );

    ok( keys %$order_nrs == 3, 'getorder_numbers returns the right number of keys' );

    cmp_deeply( $order_nrs, {
        1 => '1',
        2 => '2',
        3 => "Invalid reference: Internal reference '3' is not in a valid format.",
    }, 'getorder_numbers returns the correct data' );

}

sub test_getcustomer_saved_cards : Tests {
    my $self = shift;

    # We'll use the defaults provided by the Mock object.
    my @default_cards = @{ $self->domain->psp_saved_cards };

    # But just in case, we'll make sure it has at least a couple of them.
    cmp_ok( scalar @default_cards, '>=', 2, 'We have at least two default saved cards' );

    my $request_data = $self->card_details( qw(
        site
        userID
        cardToken
    ) );

    # We must use the same customer ID.
    $request_data->{customerID} = $self->domain->customer_id;

    # Call the method.
    my $cards = $self->domain->getcustomer_saved_cards( $request_data );

    # Check the return value is an array.
    isa_ok( $cards, 'ARRAY', 'getcustomer_saved_cards returns an ArrayRef' );

    # Check the length of the array.
    cmp_ok( scalar @$cards, '==', scalar @default_cards, 'getcustomer_saved_cards returned the right number of cards' );

    # Now check each card.
    foreach my $card_index ( 0 .. $#default_cards ) {

        my $got      = $cards->[ $card_index ];
        my $expected = $default_cards[ $card_index ];

        cmp_deeply( $got, $expected,
            "Card $card_index in the array is defined as expected" );

    }

    ## Now we've tested success, we need to test failure.

    # Delete a required attribute, so it fails.
    delete $request_data->{cardToken};

    # Call the method again, now with a missing attribute, so this time it
    # should fail.
    my $failed_cards = $self->domain->getcustomer_saved_cards( $request_data );

    # Check the return value is an array.
    isa_ok( $failed_cards, 'ARRAY', 'getcustomer_saved_cards returns an ArrayRef for a failure' );

    # Check the length of the array.
    cmp_ok( scalar @$failed_cards, '==', 0, 'getcustomer_saved_cards returned no cards for a failure' );

}

sub test_save_card : Tests {
    my $self = shift;

    # Get some fake card details.
    my $details = $self->card_details( qw(
        site
        userID
        customerID
        cardToken
        creditCardReadOnly
    ) );

    # Call the method with all the required data and make sure it returns true.
    my $result = $self->domain->save_card( $details );
    ok( $result, 'save_card returns true' );

    # Remove one of the keys, so it fails.
    delete $details->{creditCardReadOnly};

    # Call the method with some missing data and make sure it returns false.
    $result = $self->domain->save_card( $details );
    ok( ! $result, 'save_card returns false' );

}

sub test_get_new_card_token : Tests {
    my $self = shift;

    my $expected_response = $self->card_details( 'cardToken' );

    $self->domain->set_new_card_token(
        $expected_response->{cardToken}
    );

    my $result = $self->domain->get_new_card_token;

    cmp_deeply( $result, {
        customerCardToken => $expected_response->{cardToken},
        message           => undef,
        error             => undef,
    } );

}

sub ps_init {
    my ($self,  $return_reference ) = @_;

    my $data = $self->card_details( qw(
        paymentSessionId        channel         distributionCentre
        paymentMethod           currency        coinAmount
        billingCountry          isPreOrder      title
        firstName               lastName        address1
        address2                address3        postcode
        merchantUrl             email
    ) );

    my $result = $self->domain->init_with_payment_session( $data );

    return $return_reference
        ? $result->{reference}
        : $result;
}


sub ps_preauth {
    my ($self,  $init_ref ) = @_;

    my $data = $self->card_details( qw(
        paymentSessionId
        orderNumber
    ) );

    $data->{reference} = $init_ref;

    my $preauth = $self->domain->preauth_with_payment_session($data);

    return $preauth;
}


sub ps_settle {
    my ($self, $preauth_ref) = @_;

    my $data = $self->card_details( qw(
        coinAmount
        channel
        currency
    ) );

    $data->{preAuthReference} = $preauth_ref;

    $self->mock_lwp->clear_requests;
    my $settle = $self->domain->settle_payment($data);

    # Make sure the LWP request contains the correct payload.
    cmp_deeply( $self->mock_lwp->get_decoded_last_request, $data,
        'The "settle_payment" request payload was correct' );

    return $settle;
}

sub ps_refund {
    my ( $self, $settle_ref, $items ) = @_;

    my $data = $self->card_details( qw(
        coinAmount
        channel
    ) );

    $data->{reference}      = $settle_ref;
    $data->{refundItems}    = $items if defined $items;

    my $refund = $self->domain->refund_payment($data);

    return $refund;
}

# A helper method to generate a HashRef of card details, based on the
# requested list of keys.

sub card_details {
    my ($self,  @keys ) = @_;

    # These are all the available keys.
    my %available_keys = (
        address1            => '4-4-1-SomeAddress1',
        address2            => '4-4-1-SomeAddress2',
        address3            => '',
        address4            => '',
        billingCountry      => 'GB',
        cardCVSNumber       => '547',
        cardExpiryMonth     => '03',
        cardExpiryYear      => '15',
        cardHoldersName     => 'Mr O Victor-Smith',
        cardIssueNumber     => 1,
        cardNumber          => '343434100000006',
        cardToken           => '7772236b33c6b612ccfc9643099e6e133b25d229bc6045ade97b27844aa2ff97',
        cardType            => 'AMEX',
        channel             => 'NAP-PWS-INTL',
        coinAmount          => '80000',
        currency            => 'GBP',
        customerID          => '110000009',
        customerId          => '110000009',
        distributionCentre  => 'NAP-DC1',
        email               => 'dev4-4-1@net-a-porter.com',
        expiryDate          => '03/16',
        firstName           => 'Dev-4-4-1',
        isPreOrder          => '0',
        isSavedCard         => '0',
        issueNumber         => 5,
        last4Digits         => '0006',
        lastName            => 'DAVE-TEST',
        merchantURL         => 'http://www.net-a-porter.com',
        orderNumber         => Data::UUID->new->create_str,
        paymentMethod       => 'CREDITCARD',
        postcode            => 'W12 7GF',
        site                => 'nap_intl',
        startDate           => '12/12',
        title               => 'Mr.',
        userID              => 11,
        paymentSessionId    => '341e286c1630846d21fcb7134eb2050d',
        merchantUrl         => 'http://www.netaporter.com',
    );

    # Create the creditCardReadOnly group.
    $available_keys{creditCardReadOnly} = {
        cardToken       => $available_keys{cardToken},
        customerId      => $available_keys{customerId},
        expiryDate      => $available_keys{expiryDate},
        cardType        => $available_keys{cardType},
        last4Digits     => $available_keys{last4Digits},
        cardNumber      => $available_keys{cardNumber},
        cardHoldersName => $available_keys{cardHoldersName},
    };

    # Create the creditCardReadOnlyBasic group.
    $available_keys{creditCardReadOnlyBasic} = {
        customerId  => $available_keys{customerId},
        cardType    => $available_keys{cardType},
        last4Digits => $available_keys{last4Digits},
    };

    # Return a HashRef of the requested keys (if they exist).
    return {
        map  { $_ => $available_keys{ $_ } }
        grep { exists $available_keys{ $_ } }
        @keys
    };

}

sub test_update_boolean_values : Tests {
    my $self = shift;

    my $data = {
        key_1 => undef,
        key_2 => 0,
        key_3 => 1,
        key_4 => '',
        key_5 => '1'
    };

    my $expected = {
        key_1 => 'false',
        key_2 => 'false',
        key_3 => 'true',
        key_4 => 'false',
        key_5 => 'true'
    };

    my $domain = XT::Domain::Payment->new;

    $domain->_update_boolean_values( $data, keys %$data );

    cmp_deeply( $expected, $data, 'Values where updated correctly' );

}

sub domain      { return shift->{domain} }
sub mock_lwp    { return shift->domain->mock_lwp }

Test::Class->runtests;

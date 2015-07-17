package Test::XT::Domain::Payment;

use NAP::policy     qw( tt class test );

BEGIN {
    extends 'NAP::Test::Class';
};

=head1 NAME

Test::XT::Domain::Payment

=head1 DESCRIPTION

Tests the 'XT::Domain::Payment' Class. In particular it tests the following:

    * getinfo_payment
    * getorder_numbers
    * amount_exceeds_provider_threshold
    * reauthorise_address

=cut

use Test::XTracker::Mock::Net::PaymentService::Client;
use Test::XTracker::Mock::PSP;
use Mock::Quick;

use JSON;


sub startup : Tests( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    $self->{mocked_client} = Test::XTracker::Mock::Net::PaymentService::Client->mock();

    use_ok( 'XT::Domain::Payment' );
    $self->{mock_psp} = Test::XTracker::Mock::PSP->new();
    $self->{mock_lwp} = $self->{mock_psp}->get_mock_lwp;
    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state
}

sub teardown : Tests( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->{mock_lwp}->clear_requests;
    $self->{mock_lwp}->clear_responses;
    $self->{mock_lwp}->enabled( 0 );

    # specifying 'undef' will cause the default payload to be used by future tests
    Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment_response( undef );
}

sub shut_down : Tests( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown();

    # stop the mock mocking, otherwise problems
    # will occur when run with other class tests
    Test::XTracker::Mock::PSP->use_all_original_methods();
    delete $self->{mocked_client};
    delete $self->{mock_psp};
    delete $self->{mock_lwp};
}


=head1 TESTS

=head2 test_getinfo_payment_response

There is a new Service the PPT team have written that will replace the existing 'payment-info'
service and this returns data in a different way (the new service is called 'payment-information',
but we need to be able to work with both the new and the old service, so this test will ensure that
regardless of which format the response is in the 'getinfo_payment' will return the data in a
consistent format (based on the new service's response).

This test will use the mocked 'XT::Net::PaymentService::Client' to simulate the different formats
that could be passed back.

=cut

sub test_getinfo_payment_response : Tests {
    my $self = shift;

    my $payment = $self->_get_domain_payment_instance;

    my %tests = (
        "'payment-info' - Response" => {
            "providerReference" => "4300203052386735",
            "coinAmount" => "800000",
            "orderNumber" => "ORDER-2011-04-04-1",
            "email" => 'alexandra.deller@net-a-porter.com',
            "billingCountry" => "GB",
            "cv2avsStatus" => "ALL MATCH",
            "cardNumberFirstDigit" => "5",
            "cardNumberLastFourDigits" => "0001",
            "authCode" => "55AB09",
            "cardExpiryMonth" => "03",
            "cardExpiryYear" => "15",
            "cardType" => "debit mastercard",
            "address4" => undef,
            "address1" => "Westfield London",
            "address2" => "1 Ariel Way",
            "postcode" => "W12 7GF",
            "title" => "Ms.",
            "firstName" => "Test",
            "lastName" => "Tester",
            "savedCard" => 0,
            "address3" => "London",
            "cardIssuer" => "",
            "cardCategory" => "Debit Mastercard",
            "countryIssuer" => "United Kingdom",
            "cardHistory" => [
                {
                    "orderNumber" => "ORDER-2011-04-04-1",
                    "cv2avsStatus" => "ALL MATCH",
                    "cardNumberFirstDigit" => "5",
                    "cardNumberLastFourDigits" => "0001",
                    "settlements" => [
                        {
                            "settlementCoinAmount" => "800000",
                            "settlementReason" => "FULFILLED OK",
                            "success" => 1,
                            "settleReference" => 144,
                        },
                        {
                            "settlementCoinAmount" => "800000",
                            "settlementReason" => undef,
                            "success" => 0,
                            "settleReference" => 145,
                        }
                    ],
                    "preAuthProviderReturnCode" => "1",
                    "preAuthReference" => 283,
                    "success" => 1,
                    "preAuthInternalReason" => "Success",
                    "preAuthProviderReason" => "ACCEPTED",
                    "storedCard" => 0,
                    "currency" => "GBP",
                    "date" => "2013-11-25T15:20:32.000+0000"
                },
                {
                    "orderNumber" => "ORDER-2011-04-04-1",
                    "cv2avsStatus" => "ALL MATCH",
                    "cardNumberFirstDigit" => "5",
                    "cardNumberLastFourDigits" => "0001",
                    "settlements" => [
                        {
                            "settlementCoinAmount" => "800000",
                            "settlementReason" => "FULFILLED OK",
                            "success" => 1,
                            "settleReference" => 144,
                        },
                        {
                            "settlementCoinAmount" => "800000",
                            "settlementReason" => undef,
                            "success" => 0,
                            "settleReference" => 145,
                        }
                    ],
                    "preAuthProviderReturnCode" => "1",
                    "preAuthReference" => 283,
                    "success" => 1,
                    "preAuthInternalReason" => "Success",
                    "preAuthProviderReason" => "ACCEPTED",
                    "storedCard" => 0,
                    "currency" => "GBP",
                    "date" => "2013-11-25T15:20:32.000+0000"
                },
            ],
            "newCard" => 1,
            "cardAttempts" => 1,
            "preauthInternalReference" => "714-1385392819370",
            "threeDSecureResponse" => "3DSecure is not supported",
            "currency" => "GBP",
            "provider" => "datacash-intl",
            "message" => "",
            "date" => "2013-11-25T15:20:32.000+0000"
        },
        "'payment-information' - Response" => {
            "providerReference" => "4300203052386735",
            "coinAmount" => "800000",
            "orderNumber" => "ORDER-2011-04-04-1",
            "email" => 'alexandra.deller@net-a-porter.com',
            "billingCountry" => "GB",
            "paymentMethod" => "CREDITCARD",
            "firstName" => "Test",
            "lastName" => "Tester",
            "cv2avsStatus" => "ALL MATCH",
            "authCode" => "55AB09",
            "address4" => undef,
            "address1" => "Westfield London",
            "address2" => "1 Ariel Way",
            "postcode" => "W12 7GF",
            "title" => "Ms.",
            "address3" => "London",
            "preauthReference" => "714-1385392819370",
            "current_payment_status" => "ACCEPTED",
            "original_payment_status" => "ACCEPTED",
            "cardInfo" => {
                "cardNumberFirstDigit" => "5",
                "cardNumberLastFourDigits" => "0001",
                "cardExpiryMonth" => "03",
                "cardExpiryYear" => "15",
                "cardType" => "debit mastercard",
                "cardIssuer" => "",
                "cardCategory" => "Debit Mastercard",
                "countryIssuer" => "United Kingdom",
                "newCard" => 1,
                "storedCard" => 0,
                "cardAttempts" => 1,
            },
            "orderDate" => "2013-11-25T15:20:32.000+0000",
            "paymentHistory" => [
                {
                    "success" => 1,
                    "orderNumber" => "ORDER-2011-04-04-1",
                    "cv2avsStatus" => "ALL MATCH",
                    "current_payment_status" => "ACCEPTED",
                    "original_payment_status" => "ACCEPTED",
                    "paymentMethod" => "CREDITCARD",
                    "cardInfo" => {
                        "cardNumberFirstDigit" => "5",
                        "cardNumberLastFourDigits" => "0001",
                        "cardExpiryMonth" => undef,
                        "cardExpiryYear" => undef,
                        "cardType" => undef,
                        "cardIssuer" => undef,
                        "cardCategory" => undef,
                        "countryIssuer" => undef,
                        "newCard" => undef,
                        "storedCard" => 0,
                        "cardAttempts" => undef,
                    },
                    "orderDate" => "2013-11-25T15:20:32.000+0000",
                    "settlements" => [
                        {
                            "settleReference" => 144,
                            "success" => 1,
                            "settlementCoinAmount" => "800000",
                            "settlementReason" => "FULFILLED OK"
                        },
                        {
                            "settleReference" => 145,
                            "success" => 0,
                            "settlementCoinAmount" => "800000",
                            "settlementReason" => undef,
                        }
                    ],
                    "preAuthReference" => 283,
                    "preAuthInternalReason" => "Success",
                    "preAuthProviderReason" => "ACCEPTED",
                    "preAuthProviderReturnCode" => "1",
                    "currency" => "GBP"
                },
                {
                    "success" => 1,
                    "orderNumber" => "ORDER-2011-04-04-1",
                    "cv2avsStatus" => "ALL MATCH",
                    "paymentMethod" => "CREDITCARD",
                    "current_payment_status" => "ACCEPTED",
                    "original_payment_status" => "ACCEPTED",
                    "cardInfo" => {
                        "cardNumberFirstDigit" => "5",
                        "cardNumberLastFourDigits" => "0001",
                        "cardExpiryMonth" => undef,
                        "cardExpiryYear" => undef,
                        "cardType" => undef,
                        "cardIssuer" => undef,
                        "cardCategory" => undef,
                        "countryIssuer" => undef,
                        "newCard" => undef,
                        "storedCard" => 0,
                        "cardAttempts" => undef,
                    },
                    "orderDate" => "2013-11-25T15:20:32.000+0000",
                    "settlements" => [
                        {
                            "settleReference" => 144,
                            "success" => 1,
                            "settlementCoinAmount" => "800000",
                            "settlementReason" => "FULFILLED OK"
                        },
                        {
                            "settleReference" => 145,
                            "success" => 0,
                            "settlementCoinAmount" => "800000",
                            "settlementReason" => undef,
                        }
                    ],
                    "preAuthReference" => 283,
                    "preAuthInternalReason" => "Success",
                    "preAuthProviderReason" => "ACCEPTED",
                    "preAuthProviderReturnCode" => "1",
                    "currency" => "GBP"
                }
            ],
            "threeDSecureResponse" => "3DSecure is not supported",
            "currency" => "GBP",
            "provider" => "datacash-intl"
        },
    );

    # the 'getinfo_payment' method should return both of the above in
    # the same structure, so $expect works for both. Not intersted in
    # most of the values just the structure of the Response
    my $expect = {
        "providerReference" => "4300203052386735",
        "coinAmount" => "800000",
        "orderNumber" => "ORDER-2011-04-04-1",
        "email" => 'alexandra.deller@net-a-porter.com',
        "billingCountry" => "GB",
        "paymentMethod" => "CREDITCARD",
        "firstName" => "Test",
        "lastName" => "Tester",
        "cv2avsStatus" => "ALL MATCH",
        "authCode" => "55AB09",
        "address4" => undef,
        "address1" => "Westfield London",
        "address2" => "1 Ariel Way",
        "postcode" => "W12 7GF",
        "title" => "Ms.",
        "address3" => "London",
        "preauthReference" => "714-1385392819370",
        "current_payment_status" => "ACCEPTED",
        "original_payment_status" => "ACCEPTED",
        "cardInfo" => {
            "cardNumberFirstDigit" => "5",
            "cardNumberLastFourDigits" => "0001",
            "cardExpiryMonth" => "03",
            "cardExpiryYear" => "15",
            "cardType" => "debit mastercard",
            "cardIssuer" => "",
            "cardCategory" => "Debit Mastercard",
            "countryIssuer" => "United Kingdom",
            "newCard" => 1,
            "storedCard" => 0,
            "cardAttempts" => 1,
        },
        "orderDate" => "2013-11-25T15:20:32.000+0000",
        "paymentHistory" => [
            {
                "success" => 1,
                "orderNumber" => "ORDER-2011-04-04-1",
                "cv2avsStatus" => "ALL MATCH",
                "current_payment_status" => "ACCEPTED",
                "original_payment_status" => "ACCEPTED",
                "paymentMethod" => "CREDITCARD",
                "cardInfo" => {
                    "cardNumberFirstDigit" => "5",
                    "cardNumberLastFourDigits" => "0001",
                    "cardExpiryMonth" => undef,
                    "cardExpiryYear" => undef,
                    "cardType" => undef,
                    "cardIssuer" => undef,
                    "cardCategory" => undef,
                    "countryIssuer" => undef,
                    "newCard" => undef,
                    "storedCard" => 0,
                    "cardAttempts" => undef,
                },
                "orderDate" => "2013-11-25T15:20:32.000+0000",
                "settlements" => [
                    {
                        "settleReference" => 144,
                        "success" => 1,
                        "settlementCoinAmount" => "800000",
                        "settlementReason" => "FULFILLED OK"
                    },
                    {
                        "settleReference" => 145,
                        "success" => 0,
                        "settlementCoinAmount" => "800000",
                        "settlementReason" => undef,
                    }
                ],
                "preAuthReference" => 283,
                "preAuthInternalReason" => "Success",
                "preAuthProviderReason" => "ACCEPTED",
                "preAuthProviderReturnCode" => "1",
                "currency" => "GBP"
            },
            {
                "success" => 1,
                "orderNumber" => "ORDER-2011-04-04-1",
                "cv2avsStatus" => "ALL MATCH",
                "paymentMethod" => "CREDITCARD",
                "current_payment_status" => "ACCEPTED",
                "original_payment_status" => "ACCEPTED",
                "cardInfo" => {
                    "cardNumberFirstDigit" => "5",
                    "cardNumberLastFourDigits" => "0001",
                    "cardExpiryMonth" => undef,
                    "cardExpiryYear" => undef,
                    "cardType" => undef,
                    "cardIssuer" => undef,
                    "cardCategory" => undef,
                    "countryIssuer" => undef,
                    "newCard" => undef,
                    "storedCard" => 0,
                    "cardAttempts" => undef,
                },
                "orderDate" => "2013-11-25T15:20:32.000+0000",
                "settlements" => [
                    {
                        "settleReference" => 144,
                        "success" => 1,
                        "settlementCoinAmount" => "800000",
                        "settlementReason" => "FULFILLED OK"
                    },
                    {
                        "settleReference" => 145,
                        "success" => 0,
                        "settlementCoinAmount" => "800000",
                        "settlementReason" => undef,
                    }
                ],
                "preAuthReference" => 283,
                "preAuthInternalReason" => "Success",
                "preAuthProviderReason" => "ACCEPTED",
                "preAuthProviderReturnCode" => "1",
                "currency" => "GBP"
            }
        ],
        "threeDSecureResponse" => "3DSecure is not supported",
        "currency" => "GBP",
        "provider" => "datacash-intl"
    };

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $payload = $tests{ $label };

        # set what the Mocked Client should return
        Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment_response( $payload );

        my $got = $payment->getinfo_payment;
        cmp_deeply( $got, $expect, "Response from 'getinfo_payment' as Expected" );
    }
}

=head2 test_amount_exceeds_provider_threshold

This tests the 'amount_exceeds_provider_threshold' method that ultimately
calls the PSP to check if an Amount would take the Payment over the
threshold that would require a new Pre-Auth to be taken. This just tests
that the method can be called.

=cut

sub test_amount_exceeds_provider_threshold : Tests {
    my $self = shift;

    $self->{mock_psp}->set_amount_exceeds_provider_threshold_response('under');

    my $payment = $self->_get_domain_payment_instance;

    my $result = $payment->amount_exceeds_provider_threshold( {
        reference => '12345568',
        newAmount => 1234500,
    } );

    is_deeply( $result, { result => 0 } );
}

=head2 test_reauthorise_address

Tests the 'reauthorise_address' method that tells the PSP that a
Shipping Address has changed and returns amongst other things
whether the Address is Valid or not.

This tests that the correct data is passed through to the PSP
ok and that the Address fields are transformed correctly from
a DBIC 'order_address' object.

The test is run twice; once for the 'United Kingdom' and once for
'Germany'.

=cut

sub test_reauthorise_address : Tests {
    my $self = shift;

    my %tests = (
        'German Address' => {
            setup => {
                county          => 'county',
                country         => 'Germany',
                address_line_1  => 'Gällerstraße 123',
            },
            expected => {
                houseNumber     => '123',
                streetName      => 'Gällerstraße',
                address1        => 'Gällerstraße 123',
            }
        },
        'English Address' => {
            setup => {
                county          => 'county',
                country         => 'United Kingdom',
                address_line_1  => 'Test Street 123',
            },
            expected => {
                houseNumber     => '',
                streetName      => '',
                address1        => 'Test Street 123',
            }
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest $name => sub {

            my $address = Test::XTracker::Data->create_order_address_in('current_dc');
            $address->update( $test->{setup} )->discard_changes;

            my $args    = {
                reference     => '12345568',
                order_number  => '12321313',
                customer_name => 'Cust Omer',
                first_name    => 'Cust',
                last_name     => 'Omer',
                address       => $address,
            };

            # define what the Request Content is expected to be
            my %expect  = (
                reference       => $args->{reference},
                orderNumber     => $args->{order_number},
                customerName    => $args->{customer_name},
                firstName       => $args->{first_name},
                lastName        => $args->{last_name},
                shippingAddress => {
                    %{ $test->{expected} },
                    address2        => $address->address_line_2,
                    city            => $address->towncity,
                    stateOrProvince => $address->county,
                    postcode        => $address->postcode,
                    country         => $address->country_ignore_case
                                                ->code,
                },
            );

            my $payment = $self->_get_domain_payment_instance;

            note "Test 'reauthorise_address' method fails when called without proper arguments";
            foreach my $key ( keys %{ $args } ) {
                my %test_args = %{ $args };
                delete $test_args{ $key };
                throws_ok {
                        $payment->reauthorise_address( \%test_args );
                    } qr/${key}.*required/i,
                    "method failed when '${key}' not passed"
                ;
            }

            # make sure the 'address' argument needs to be an Object
            $args->{address} = { address_line_1 => '1 The Road' };
            throws_ok {
                    $payment->reauthorise_address( $args );
                } qr/address.*Object/i,
                "method failed when 'address' is NOT an Object"
            ;

            # put 'address' back how it should be
            $args->{address} = $address;

            note "Test Request Sent and the Response received from calling 'reauthorise_address'";
            $self->{mock_lwp}->clear_requests;
            $self->{mock_psp}->set_reauthorise_address_response('address_valid');

            my $result       = $payment->reauthorise_address( $args );
            my $request      = $self->{mock_lwp}->get_last_request;
            my $request_data = JSON->new->utf8->decode( $request->content );

            cmp_deeply( $request_data, \%expect, "Data sent in the Request is as Expected" );
            cmp_deeply( $result, superhashof{ returnCodeResult => 1 }, "Result is as Expected" );

        }

    }

}


sub test_get_refund_information : Tests {
    my $self = shift;

    my $payment = $self->_get_domain_payment_instance;

    my $valid_data = [
        {
            reason          => 'ACCEPTED',
            success         => 'true',
            amountRefunded  => 38574,
            dateRefunded    => '2014-09-03T09:30:04.000+0000',
        },
        {
            reason          => 'FAILED',
            success         => 'false',
            amountRefunded  => 38574,
            dateRefunded    => '2014-09-03T09:30:04.000+0000',
        },
    ];

    my %tests = (
        'Valid Data' => {
            data            => $valid_data,
            expected        => $valid_data,
            last_warning    => undef,
        },
        'Not an Array' => {
            data            => { not_an => 'array' },
            expected        => [],
            last_warning    => qr/response is not an array/,
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        subtest $name => sub {

            my $last_warning;

            my $mock = qtakeover( 'Log::Log4perl::Logger' );
            $mock->override( warn => sub { $last_warning = $_[1] } );

            $self->{mock_lwp}->clear_requests;
            $self->{mock_psp}->set__get_refund_information__response( JSON->new->encode( $test->{data} ) );

            my $result = $payment->get_refund_information( 'REFERENCE' );

            if ( defined $test->{last_warning} ) {
                like( $last_warning, $test->{last_warning}, "The last warning is as expected: $test->{last_warning}" );
            } else {
                ok( ! defined $last_warning, 'There where no warnings logged' );
            }

            cmp_bag( $result, $test->{expected},
                'The response from get_refund_information is as expected' );

            $mock->restore('warn');
            $mock = undef;
        };

    }

}


sub test_payment_amendment : Tests {
    my $self = shift;

    my $payment = $self->_get_domain_payment_instance;

    my $valid_response  = {
        returnCodeResult => 1,
        returnCodeReason => 'Success',
        extraReason      => 'Made the call succesfully ',
        reference        => 'XXXX'
    };
    my $invalid_response = {
        'reference' => undef,
        'returnCodeReason' => "XTracker Error",
        'returnCodeResult' => 9999,
        'extraReason'      => re( qr/Failed to make payment-amendement call to PSP \[PaymentService Error\]/i ),
    };

    my $expected= {
        valid_response => $valid_response,
        invalid_response => $invalid_response,
    };

    my $got;
    # Test for Valid Response
    $self->{mock_lwp}->clear_requests;
    $self->{mock_psp}->set__payment_amendment__response(JSON->new->encode( $valid_response)) ;
    $got->{valid_response}  = $payment->payment_amendment( {reference => 'test'} );

    # Test call dies.
    $self->{mock_lwp}->clear_requests;
    $self->{mock_psp}->set__payment_amendment__response_die;
    $got->{invalid_response} = $payment->payment_amendment( {} );


    cmp_deeply($got, $expected, "payment-amedment method calls works as expected");
}

sub test_payment_replacement: Tests {
    my $self = shift;

    my $payment = $self->_get_domain_payment_instance;

    my $valid_response  = {
        returnCodeResult => 1,
        returnCodeReason => 'Success',
        extraReason      => 'Made the call succesfully ',
        reference        => 'XXXX'
    };
    my $invalid_response = {
        'reference' => undef,
        'returnCodeReason' => "XTracker Error",
        'returnCodeResult' => 9999,
        'extraReason'      => re( qr/Failed to make payment-replacement call to PSP \[PaymentService Error\]/i ),
    };

    my $expected= {
        valid_response => $valid_response,
        invalid_response => $invalid_response,
    };

    my $got;
    # Test for Valid Response
    $self->{mock_lwp}->clear_requests;
    $self->{mock_psp}->set__payment_replacement__response(JSON->new->encode( $valid_response)) ;
    $got->{valid_response}  = $payment->payment_replacement( {reference => 'test'} );

    # Test call dies.
    $self->{mock_lwp}->clear_requests;
    $self->{mock_psp}->set__payment_replacement__response_die;
    $got->{invalid_response} = $payment->payment_replacement( {} );


    cmp_deeply($got, $expected, "payment-replacement method calls works as expected");
}


#----------------------------------------------------------------------------

sub _get_domain_payment_instance {
    my $self = shift;

    return XT::Domain::Payment->new();
}


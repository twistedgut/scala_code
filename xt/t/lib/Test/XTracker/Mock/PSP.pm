package Test::XTracker::Mock::PSP;
use NAP::policy "tt",     'test';

=head1 NAME

Test::XTracker::Mock::PSP - Mocks the PSP Service

=head1 DESCRIPTION

Use to mock calls to the PSP Service, contains various methods to
set up responses you'd like to have the PSP return for your tests.

If you're using this Class in 'Test::Class' tests then please do
the following in the 'startup' & 'shutdown' test methods so as
to prevent your Test from being effected by a previous test and
to prevent your Test from affecting a subsequent test:

    sub test_startup : Test( startup => no_plan ) {
        ...
        # get the Mocked Class in a known state at the begining
        Test::XTracker::Mock::PSP->use_all_mocked_methods();
        ...
    }

    sub test_shutdown : Test( shutdown => no_plan ) {
        ...
        # essentially Stop the Mocking
        Test::XTracker::Mock::PSP->use_all_original_methods();
        ...
    }

=cut

use Test::MockObject;
use Data::Dump 'pp';
use Data::UUID;

use Test::XTracker::Data;

use Test::XTracker::Mock::Net::PaymentService::Client;
use Test::XTracker::Mock::LWP;

my $_mock_xt_domain_payment;
my $_payment_service_client_mock;
my $_mock_lwp;

# store the code refs. to original Methods
my %_original_methods;

# methods in this hash will cause the mocked method to
# call the original method stored in '%_original_methods'
# using this requires a line of code to be added to each
# mocked method, otherwise nothing will happen, see the
# docs on the method 'use_original_method' for more info
my %_use_original_method;


BEGIN {
    # list of methods from 'XT::Domain::Payment' which are
    # to be Mocked and have a corresponding method in this
    # Class that will be used when Mocking
    my @methods_to_mock = ( qw(
        cancel_preauth
        settle_payment
        refund_payment
        getorder_numbers
        getcustomer_saved_cards
        save_card
        create_new_payment_session
        get_card_details_status
        init_with_payment_session
        preauth_with_payment_session
    ) );

    # store original method code refs. for 'XT::Domain::Payment'
    foreach my $method ( @methods_to_mock ) {
        my $mop_method = XT::Domain::Payment->meta->get_method( $method );
        $_original_methods{ $method } = $mop_method->body;
    }

    # use Test::MockObject to inject our own method
    $_mock_xt_domain_payment = Test::MockObject->new;
    $_mock_xt_domain_payment->fake_module(
        'XT::Domain::Payment',

        # mock methods from the class:
        map { $_ => \&${_} } @methods_to_mock,

        # add in extra methods to support mocking:
        settle_action                       => \&settle_action,
        get_settle_data_in                  => \&get_settle_data_in,
        cancel_action                       => \&cancel_action,
        get_cancel_data_in                  => \&get_cancel_data_in,
        refund_action                       => \&refund_action,
        refund_extra                        => \&refund_extra,
        get_refund_data_in                  => \&get_refund_data_in,
        get_init_data_in                    => \&get_init_data_in,
        preauth_payment                     => \&preauth_payment,
        set_init_payment_return_code        => \&set_init_payment_return_code,
        set_preauth_payment_return_code     => \&set_preauth_payment_return_code,
        set_settle_payment_return_code      => \&set_settle_payment_return_code,
        set_preauth_death                   => \&set_preauth_death,
        clear_method_calls                  => \&clear_method_calls,
        next_method_call                    => \&next_method_call,
        all_method_calls                    => \&all_method_calls,
        log_method_call                     => \&log_method_call,
        get_init_with_payment_session_in    => \&get_init_with_payment_session_in,
        'set__preauth_with_payment_session__response__success'
                                            => \&set__preauth_with_payment_session__response__success,
        'set__preauth_with_payment_session__response__not_authorised'
                                            => \&set__preauth_with_payment_session__response__not_authorised,
        'set__preauth_with_payment_session__response__die'
                                            => \&set__preauth_with_payment_session__response__die,
        'set__create_new_payment_session__response'
                                            => \&set__create_new_payment_session__response,
        'set__create_new_payment_session__response__success'
                                            => \&set__create_new_payment_session__response__success,
        'set__create_new_payment_session__response__die'
                                            => \&set__create_new_payment_session__response__die,
        is_mocked                           => \&is_mocked,
        'set__get_card_details_status__response__success'
                                            => \&set__get_card_details_status__response__success,
        'set__get_card_details_status__response__failure'
                                            => \&set__get_card_details_status__response__failure,
        'set__get_refund_information__response'
                                            => \&set__get_refund_information__response,
        'set__payment_amendment__response'   => \&set__payment_amendment__response,
        'set__payment_amendment__response_die'   => \&set__payment_amendment__response_die,

    );

    # instead of mocking 'XT::Domain::Payment' we should be mocking the service that
    # it calls. Don't have time to do all services used so start with 'getinfo_payment'
    $_payment_service_client_mock = Test::XTracker::Mock::Net::PaymentService::Client->mock();

    # unfortunately another way of mocking the PSP, this time this should be the way
    # forward. Mock LWP so that we can pass in the response to any service and have
    # it go through all the code so as to find the maximum amount of errors (should
    # there be any).
    $_mock_lwp = Test::XTracker::Mock::LWP->new();
}

use Moose;
    extends 'XT::Domain::Payment';

use XTracker::Constants::Payment qw( :psp_return_codes );


=head1 METHODS

=head2 get_xt_domain_payment_mock

Returns the Mock Object that is mocking XT::Domain::Payment

=cut

sub get_xt_domain_payment_mock {
    return $_mock_xt_domain_payment;
}

=head2 use_original_method

    __PACKAGE__->use_original_method( "name_of_method" );

This will tell the Mocked Method to call the Original Method
and return. For this to work the Mocked Method must have
the following line of code in it at the beginning of the method
otherwise nothing will change:

    sub some_mocked_method {
        my ( $self, $param1, $param2 ) = @_;

        return $_original_methods{some_mocked_method}->( @_ )   if ( $_use_original_method{some_mocked_method} );

        ...
    }

=cut

sub use_original_method {
    my ( $self, $method_name ) = @_;

    $_use_original_method{ $method_name } = 1;

    return;
}

=head2 use_mocked_method

    __PACKAGE__->use_mocked_method( "name_of_method" );

Will cause the Mocked Method to be used instead of calling the
original. Use with '__PACKAGE__->use_original_method'.

=cut

sub use_mocked_method {
    my ( $self, $method_name ) = @_;

    delete $_use_original_method{ $method_name };

    return;
}

=head2 use_all_mocked_methods

    __PACKAGE__->use_all_mocked_methods();

This will use all the Mocked Methods that this Class has been set-up
to Mock. This is particulary useful in 'Test::Class' tests where
a previous Test Class might have called 'use_all_original_methods' and
so calling this will re-activate the Mock.

=cut

sub use_all_mocked_methods {
    my $self = shift;

    # loop round all methods that have been
    # Mocked and make sure they will be used
    foreach my $method ( keys %_original_methods ) {
        $self->use_mocked_method( $method );
    }

    return;
}

=head2 use_all_original_methods

    __PACKAGE__->use_all_original_methods()

This will cause this Class to Call the Original Methods
that this Class has Mocked instead of the Mocked versions.
This is particulary useful in 'Test::Class' tests where at
the end of your Test Class you should call this so as to
not interfere with a subsequent Class that isn't expecting
the methods to be Mocked.

=cut

sub use_all_original_methods {
    my $self = shift;

    # loop round all methods that have been
    # Mocked and get them to use their Original
    foreach my $method ( keys %_original_methods ) {
        $self->use_original_method( $method );
    }

    return;
}

=head2 get_mock_lwp

Returns the Mock LWP used in this module.

=cut

sub get_mock_lwp {
    return $_mock_lwp;
}

=head2 disable_mock_lwp

Disables the Mocking of LWP. This should be used
at the end of every test so as to not break other
tests.

=cut

sub disable_mock_lwp {
    my $self = shift;
    $_mock_lwp->enabled(0);
    return;
}

=head2 enable_mock_lwp

Enables mocking of LWP, this should be done by any helper
used to set-up responses but might be useful to use in some
other cases independantly.

=cut

sub enable_mock_lwp {
    my $self = shift;
    $_mock_lwp->enabled(1);
    return;
}


my $init_payment_return_code = $PSP_RETURN_CODE__3D_SECURE_BYPASSED;
my $init_data_in;
sub set_init_payment_return_code {
    my ($self, $code) = @_;
    $init_payment_return_code = $code;
}

sub init_payment {
    my $self = shift;
    my ( $params ) = @_;

    log_method_call( 'init_payment', \@_ );

    $init_data_in    = $params;

    my @required_params = qw(
        cardNumber
        cardExpiryMonth
        cardExpiryYear
        cardCVSNumber
        cardIssueNumber
        coinAmount
        currency
        email
        title
        firstName
        lastName
        address1
        address2
        address3
        address4
        postcode
        billingCountry
        channel
        distributionCentre
        paymentMethod
        isPreOrder
        isSavedCard
        merchantURL
    );

    # FAIL if 'order_nr' has been passed as this
    # doesn't work anymore with the RESTful Interface
    if ( exists( $params->{order_nr} ) ) {
        fail("PSP: Can't pass 'order_nr' to 'init_payment' call");
    }

    my $psp_reference = Test::MockObject->new();
    $psp_reference->set_always('numify', int(rand(12345)));

    foreach my $required_param (@required_params) {
        unless (exists($params->{$required_param})) {
            return {
                InitResponse => {
                    returnCodeResult => $PSP_RETURN_CODE__MISSING_INFO,
                    extraReason      => "Can't find: '${required_param}'",
                }
            }
        }
    }

    return {
        InitResponse => {
            returnCodeResult => $init_payment_return_code,
            reference        => $psp_reference,
        }
    };

}

# return the data passed in to be checked by a test
sub get_init_data_in {
    return $init_data_in;
}

my $preauth_payment_return_code = $PSP_RETURN_CODE__SUCCESS;
sub set_preauth_payment_return_code {
    my ($self, $code) = @_;
    $preauth_payment_return_code = $code;
}

my $preauth_death = 0;
sub set_preauth_death {
    my ($self, $bool) = @_;
    $preauth_death = $bool;
}

sub preauth_payment {
    my $self = shift;
    my ( $params ) = @_;

    log_method_call( 'preauth_payment', \@_ );

    die if ($preauth_death);

    my @required_params = qw(
        orderNumber
        initReference
        cardNumber
        cardCVSNumber
    );

    my $psp_refs    = Test::XTracker::Data->get_new_psp_refs();

    my $psp_reference = Test::MockObject->new();
    $psp_reference->set_always('numify', $psp_refs->{preauth_ref} );

    foreach my $required_param (@required_params) {
        unless (exists($params->{$required_param})) {
            return {
                PreauthResponse => {
                    returnCodeResult => $PSP_RETURN_CODE__MISSING_INFO,
                }
            }
        }
    }

    return {
        PreauthResponse => {
            returnCodeResult => $preauth_payment_return_code,
            reference        => $psp_reference,
        }
    }
}

sub set_coin_amount {
    my ($self, $amount) = @_;

    return Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment__coin_amount(
        $amount,
    );
}

# Set Currency
sub set_payment_currency {
    my ($self, $currency ) = @_;

    return Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment__currency(
        $currency,
    );

}

# Set card history to ArrayRef.
sub set_card_history {
    my ($self,  $history ) = @_;

    return Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment__payment_history(
        $history,
    );
}

# Set card history to Default.
sub set_card_history_to_default {
    my $self = shift;

    return Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment__payment_history__default;
}

# Set card settlements to ArrayRef.
sub set_card_settlements {
    my ($self,  $settlements) = @_;

    return Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment__settlements(
        $settlements,
    );
}

# Set card settlements to Default.
sub set_card_settlements_to_default {
    my ($self) = @_;

    return Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment__settlements__default;
}

# Set AVS Response
sub set_avs_response {
    my ( $self, $response ) = @_;

    Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment__avs_response(
        $response,
    );

    return;
}

# Set AVS Response to Default
sub set_avs_response_to_default {
    my ( $self ) = @_;

    Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment__avs_response__default;

    return;
}

# set the Payment Method, currently it can be
#       * Card
#       * PayPal
#       * Klarna
sub set_payment_method {
    my ( $self, $method, $force ) = @_;

    Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment__payment_method(
        $method,
        $force,
    );

    return;
}

# set the Third Party PSP Current Status
# use this for testing Third Party payment
# methods such as PayPal
sub set_third_party_status {
    my ( $self, $status, $force ) = @_;

    Test::XTracker::Mock::Net::PaymentService::Client->set_getinfo_payment__third_party_status(
        $status,
        $force,
    );

    return;
}

# use this to set the response coming back for
# a call to the 'update_authorisation' service
sub set_reauthorise_address_response {
    my ( $self, $type ) = @_;

    my %valid_address_responses = (
        address_valid   => $_mock_lwp->response_OK(
                '{ "returnCodeResult":1,"returnCodeReason":"Success" }',
            ),
        address_invalid => $_mock_lwp->response_OK(
                '{' .
                  '"returnCodeResult":-3,' .
                  '"returnCodeReason":"Payment Provider reported issues with data received, check extra reason",' .
                  '"extraReason":"Address Invalid"' .
                '}',
            ),
        general_error   => $_mock_lwp->response_OK(
                '{' .
                  '"returnCodeResult":3,' .
                  '"returnCodeReason":"Validation error (invalid data or no corresponding transaction)",' .
                  '"extraReason":"Invalid Data or Something"' .
                '}',
            ),
        failure         => $_mock_lwp->response_INTERNAL_SERVER_ERROR(),
    );

    if ( !$type || !exists( $valid_address_responses{ $type } ) ) {
        fail( "Don't know what to mock-up for: '" . ( $type // 'undef' ) . "'" );
        return;
    }

    $self->enable_mock_lwp;
    $_mock_lwp->clear_responses;
    $_mock_lwp->add_response( $valid_address_responses{ $type } );

    return;
}

# use this to set the response coming back for
# a call to the 'threshold_value_exceeded' service
sub set_amount_exceeds_provider_threshold_response {
    my ( $self, $type ) = @_;

    my %threshold_responses = (
        over  => $_mock_lwp->response_OK( '{ "result":1 }' ),
        under => $_mock_lwp->response_OK( '{ "result":0 }' ),
        fail  => $_mock_lwp->response_INTERNAL_SERVER_ERROR(),
    );

    if ( !$type || !exists( $threshold_responses{ $type } ) ) {
        fail( "Don't know what to mock-up for: '" . ( $type // 'undef' ) . "'" );
        return;
    }

    $self->enable_mock_lwp;
    $_mock_lwp->clear_responses;
    $_mock_lwp->add_response( $threshold_responses{ $type } );

    return;
}


# override the PSP method to take the money
my $settle_action   = 'PASS';
my $settle_data_in;

my $settle_payment_return_code = $PSP_RETURN_CODE__SUCCESS;
sub set_settle_payment_return_code {
    my ($self, $code) = @_;
    $settle_payment_return_code = $code;
}

sub settle_payment {
    my $self = shift;
    my ( $params ) = @_;

    log_method_call( 'settle_payment', \@_ );

    return $_original_methods{settle_payment}->( $self, @_ )       if ( $_use_original_method{settle_payment} );

    # set a variable to be accessed by a test
    # to check the data passed in

    $settle_data_in = $params;

    my @required_params = qw(
        channel
        coinAmount
        reference
    );

    my $psp_refs    = Test::XTracker::Data->get_new_psp_refs();

    my $psp_reference = Test::MockObject->new();
    $psp_reference->set_always('numify', $psp_refs->{settle_ref} );

    foreach my $required_param (@required_params) {
        unless (exists($params->{$required_param})) {
            return {
                SettleResponse => {
                    returnCodeResult => $PSP_RETURN_CODE__MISSING_INFO,
                    reference        => $psp_reference,
                    extraReason      => 'to err is human'
                }
            }
        }
    }

    if ( $settle_payment_return_code && $settle_payment_return_code == $PSP_RETURN_CODE__SUCCESS ) {
        return {
            SettleResponse => {
                returnCodeResult => $settle_payment_return_code,
                reference        => 'TEST_RESULT-' . $params->{reference},
            },
        };
    }
    else {
        return {
            SettleResponse => {
                returnCodeResult => $settle_payment_return_code,
                ( defined $settle_payment_return_code ? ( extraReason => 'to err is human' ) : () ),
            },
        };
    }
}

# return the data passed in to be checked by a test
sub get_settle_data_in {
    return $settle_data_in;
}

# override the PSP method to cancel a pre_auth
my $cancel_action   = 'PASS';
my $cancel_data_in;
sub cancel_preauth {
    my $self = shift;
    my ( $data ) = @_;

    log_method_call( 'cancel_preauth', \@_ );

    return $_original_methods{cancel_preauth}->( $self, @_ )       if ( $_use_original_method{cancel_preauth} );

    # set a variable to be accessed by a test
    # to check the data passed in
    $cancel_data_in    = $data;

    my $result;

    if ( $cancel_action eq "PASS" ) {
        $result  = {
                CancelResponse => {
                    returnCodeResult    => 1,
                    returnCodeReason    => 'Success',
                    reference           => 'TEST_RESULT-'.$data->{preAuthReference},
                    provider            => 'test-psp',
                },
            };
    }
    else {
        my ($fail_type) = ( $cancel_action  =~ m/FAIL-(.*)/ );
        CASE: {
            if ( $fail_type eq "undef" ) {
                # return undefined
                last;
            }
            # normal failure
            $result = {
                    CancelResponse => {
                        returnCodeResult    => -1,
                        returnCodeReason    => 'An Error Occured',
                        reference           => 'FAIL_TEST_RESULT-'.$data->{preAuthReference},
                        extraReason         => 'Extra Reason for Failure',
                        provider            => 'test-psp',
                    },
            };
            if ( $fail_type eq "no_reason_or_ref" ) {
                delete $result->{CancelResponse}{reference};
                delete $result->{CancelResponse}{extraReason};
            }
        };
    }

    return $result;
}

# set whether the cancel action should pass or fail
sub cancel_action {
    $cancel_action  = $_[1];
}

# a method that returns the data that
# was sent to the 'cancel_preauth' method
sub get_cancel_data_in {
    my $self    = shift;
    return $cancel_data_in;
}

my $refund_data_in;
my $refund_action = 'PASS';
my $refund_extra = '';

sub refund_payment {
    my $self = shift;
    my ( $data ) = @_;

    log_method_call( 'refund_payment', \@_ );

    return $_original_methods{refund_payment}->( $self, @_ )       if ( $_use_original_method{refund_payment} );

    $refund_data_in = $data;

    my $refund_response = 0;

    if ( $refund_action eq 'PASS' ) {

        $refund_response = 1;

    } elsif ( $refund_action =~ /^FAIL-(\d+)$/ ) {

        $refund_response = $1
            if $1 > 1; # 1 = Success

    }

    return {
        RefundResponse  => {
            returnCodeResult    => $refund_response,
            extraReason         => $refund_extra,
        },
    };

}

sub refund_action {
    $refund_action = $_[1];
}

sub refund_extra {
    $refund_extra = $_[1];
}

sub get_refund_data_in {
    return $refund_data_in;
}

# Respond with an order number for each transaction reference number passed
# in the input array
sub getorder_numbers {
    my $self = shift;
    my ( $data ) = @_;

    return $_original_methods{getorder_numbers}->( $self, @_ )       if ( $_use_original_method{getorder_numbers} );

    log_method_call( 'getorder_numbers', \@_ );

    if ( ref $data eq 'HASH' ) {
        $data = $data->{initialReferences}->{string};
    };

    my $ref = 0;
    my $result = {
        map { $_ => ++$ref } @{$data}
    };

    return $result;
}

# Return four copies of some dummy data in an ArrayRef.
sub getcustomer_saved_cards {
    my $self = shift;
    my ( $data ) = @_;

    log_method_call( 'getcustomer_saved_cards', \@_ );

    return $_original_methods{getcustomer_saved_cards}->( $self, @_ )      if ( $_use_original_method{getcustomer_saved_cards} );

    my $date        = DateTime->now();
    my $start_date  = $date->subtract( months => 3 );
    my $expiry_date = $date->add( months => 3 );

    my $result = {
        timestamp       => $date->strftime('%FT%T.%3N%z'),
        cardType        => 'ELECTRON',
        last4Digits     => 6,
        cardHolderName  => 'Some Customer',
        issueNumber     => '',
        expiryDate      => $expiry_date->strftime("%m/%y"),
        startDate       => $start_date->strftime("%m/%y"),
    };

    return [ ( $result ) x 4 ];

}

sub save_card {
    my $self = shift;
    my ( $data ) = @_;

    return $_original_methods{save_card}->( $self, @_ )     if ( $_use_original_method{save_card} );

    log_method_call( 'save_card', \@_ );

    return 1;

}

=head2 unmock_payment_service_client

    when run under test_class for some test we might need the original class than the mocked one
    In such cases you can use unmock_payment_service_client in the start_up but do not forget
    to mock it again for all other tests by using mock_payment_service_client.

    ## TODO : We need better way to mock services!

=cut

sub unmock_payment_service_client {
    $_payment_service_client_mock->unmock_all();
}


=head2 mock_payment_service_client

    Mocks Net::PaymentService::Client Module

=cut

sub mock_payment_service_client {
    $_payment_service_client_mock = Test::XTracker::Mock::Net::PaymentService::Client->mock();
}

{

    my @method_calls;
    sub clear_method_calls { @method_calls = () }
    sub next_method_call { return shift @method_calls }
    sub all_method_calls { return @method_calls }
    sub log_method_call { push @method_calls, { method => shift, arguments => shift } }

}

=head2 create_new_payment_session

Mocked version of the C<create_new_payment_session> method.

By default it returns:

    'ded2404ad7493d2f8b809f5dea674f40'

You can set the return value by calling C<set__create_new_payment_session__response>

    $mock->set__create_new_payment_session__response( 'mypaymentsessionid' );

There are some helper methods:

    set__create_new_payment_session__response
    set__create_new_payment_session__response__success
    set__create_new_payment_session__response__die

=cut

my $create_new_payment_session_response;

sub set__create_new_payment_session__response {
    my ($self,  $response ) = @_;
    $create_new_payment_session_response = $response;
}

sub set__create_new_payment_session__response__success {
    my $self = shift;
    $create_new_payment_session_response = 'ded2404ad7493d2f8b809f5dea674f40';
}

sub set__create_new_payment_session__response__die {
    my $self = shift;
    $create_new_payment_session_response = '___DIE___';
}

sub create_new_payment_session {
    my $self = shift;
    my ( $client_session_id, $card_token ) = @_;

    return $_original_methods{create_new_payment_session}->( $self, @_ )        if ( $_use_original_method{create_new_payment_session} );

    log_method_call( 'create_new_payment_session', \@_ );

    die 'create_new_payment_session died'
        if $create_new_payment_session_response eq '___DIE___';

    return $create_new_payment_session_response;
}

=head2 get_card_details_status

Mocked version of C<get_card_details_status> method.

By default it returns:

    {
        errorCodes  => undef,
        valid       => 'true',
        cardDetails => {
            expiryYear      => '15',
            cardType        => 'VISA',
            expiryMonth     => '03',
            cardHoldersName => 'Mrs Test Tester',
        },
    }

You can the return value by calling C<set__get_card_details_status__response>

    $mock->set__get_card_details_status__response( { ... } );

=cut

my $get_card_details_status_response;

sub set__get_card_details_status__response {
    my ($self,  $response ) = @_;
    $get_card_details_status_response = $response;
}

sub set__get_card_details_status__response__success {

    $get_card_details_status_response =  {
        errorCodes  => undef,
        valid       => 1,
        cardDetails => {
            expiryYear      => '15',
            cardType        => 'VISA',
            expiryMonth     => '03',
            cardHoldersName => 'Mrs Test Tester',
        },
    };

}

sub set__get_card_details_status__response__failure {

    $get_card_details_status_response =  {
       errors => {
          54007 => 'Card Number too long or too short',
          54008 => 'Invalid Card Number i.e failed luhn check',
       },
       valid        => 0,
       cardDetails  => {
          expiryYear        => 15,
          cardType          => 'VISA',
          expiryMonth       => '03',
          cardHoldersName   => 'Mrs Test Tester',
       }
    };

}

sub get_card_details_status {
    my $self = shift;
    my ( $payment_session_id ) = @_;

    return $_original_methods{get_card_details_status}->( $self, @_ )       if ( $_use_original_method{get_card_details_status} );

    log_method_call( 'get_card_details_status', \@_ );

    return $get_card_details_status_response;
}

=head2 init_with_payment_session

Mocked version of C<init_with_payment_session> method.

By default it returns:

    {
        returnCodeResult    => 8,
        returnCodeReason    => '3DSecure is not supported',
        pareq               => undef,
        acsUrl              => undef,
        extraReason         => undef,
        provider            => 'datacash-intl',
        reference           => 1, # incrementing with each call,
    }

You can the return value by calling C<set__init_with_payment_session__response>

    $mock->set__init_with_payment_session__response( { ... } );

=cut

my $init_with_payment_session_in;
my $init_with_payment_session_response =  {
    returnCodeResult    => 8,
    returnCodeReason    => '3DSecure is not supported',
    pareq               => undef,
    acsUrl              => undef,
    extraReason         => undef,
    provider            => 'datacash-intl',
    # reference will be added automatically.
};

sub set__init_with_payment_session__response {
    my ($self,  $response ) = @_;
    $init_with_payment_session_response = $response;
}

sub init_with_payment_session {
    my $self = shift;
    my ( $params ) = @_;

    return $_original_methods{init_with_payment_session}->( $self, @_ )     if ( $_use_original_method{init_with_payment_session} );

    log_method_call( 'init_with_payment_session', \@_ );

    my @required_params = qw(
        paymentSessionId
        channel
        distributionCentre
        paymentMethod
        currency
        coinAmount
        billingCountry
        isPreOrder
        title
        firstName
        lastName
        address1
        address2
        address3
        postcode
        merchantUrl
        email
    );

    # FAIL if 'order_nr' has been passed as this
    # doesn't work anymore with the RESTful Interface
    if ( exists( $params->{order_nr} ) ) {
        fail("PSP: Can't pass 'order_nr' to 'init_payment' call");
    }

    foreach my $required_param (@required_params) {
        unless (exists($params->{$required_param})) {
            $init_with_payment_session_response->{returnCodeResult} = $PSP_RETURN_CODE__MISSING_INFO;
            $init_with_payment_session_response->{returnCodeReason} = "Can't find: '${required_param}'";
        }
    }

    $init_with_payment_session_in = $params;
    return _add_reference( $init_with_payment_session_response );

}

sub get_init_with_payment_session_in {
    return $init_with_payment_session_in;
}

=head2 preauth_with_payment_session

Mocked version of C<preauth_with_payment_session> method.

By default it will die:

You can the return value by calling C<set__preauth_with_payment_session__response>

    $mock->set__preauth_with_payment_session__response( { ... } );

There are some pre-canned responses:

    $mock->set__preauth_with_payment_session__response__success
    $mock->set__preauth_with_payment_session__response__not_authorised
    $mock->set__preauth_with_payment_session__response__die

=cut

my $preauth_with_payment_session_response;

sub set__preauth_with_payment_session__response__success {
    my $self = shift;

    $preauth_with_payment_session_response = {
        returnCodeResult    => 1,
        returnCodeReason    => 'Success',
        authCode            => '976728',
        cv2AvsStatus        => 'SECURITY CODE MATCH ONLY',
        extraReason         => 'ACCEPTED',
        provider            => 'datacash-intl',
        # reference will be added automatically.
    };

}

sub set__preauth_with_payment_session__response__not_authorised {
    my $self = shift;

    $preauth_with_payment_session_response = {
        returnCodeResult    => 2,
        returnCodeReason    => 'Not authorised',
        authCode            => 'DECLINED',
        cv2AvsStatus        => undef,
        extraReason         => 'DECLINED',
        provider            => 'datacash-intl',
        # reference will be added automatically.
    }

}

sub set__preauth_with_payment_session__response__die {
    my $self = shift;

    $preauth_with_payment_session_response = undef;

}

sub set__preauth_with_payment_session__response {
    my ($self,  $response ) = @_;
    $preauth_with_payment_session_response = $response;
}

sub preauth_with_payment_session {
    my $self = shift;
    my ( $data ) = @_;

    return $_original_methods{preauth_with_payment_session}->( $self, @_ )      if ( $_use_original_method{preauth_with_payment_session} );

    log_method_call( 'preauth_with_payment_session', \@_ );

    return _add_reference( $preauth_with_payment_session_response );
}

=head2 set__get_refund_information__response( $response )

Set the response for the get_refund_information method call. The given
C<$response> is injected directly into the mocked LWP client.

=cut

sub set__get_refund_information__response {
    my ($self,  $response ) = @_;

    $self->enable_mock_lwp;
    $_mock_lwp->clear_responses;
    $_mock_lwp->add_response( $_mock_lwp->response_OK( $response ) );

    return;
}

=head2 set__payment_amendment__response( $response )

Set the response for the payment_amendement method call. The given
C<$response> is injected directly into the mocked LWP client.

=cut

sub set__payment_amendment__response {
    my $self = shift;
    my ( $response ) = @_;

    $self->enable_mock_lwp;
    $_mock_lwp->clear_responses;
    $_mock_lwp->add_response( $_mock_lwp->response_OK( $response ) );

    return;
}

=head2 set__payment_amendment__response_die

Set the response for payment_amendment method call to undef.
Which is treated as a die in method calls.

=cut

sub set__payment_amendment__response_die {
    my $self = shift;

    return $_mock_lwp->add_response($_mock_lwp->response_INTERNAL_SERVER_ERROR());
}

=head2 set__payment_replacement__response( $response )

Set the response for the payment_replacement method call. The given
C<$response> is injected directly into the mocked LWP client.

=cut

sub set__payment_replacement__response {
    my $self = shift;
    my ( $response ) = @_;

    $self->enable_mock_lwp;
    $_mock_lwp->clear_responses;
    $_mock_lwp->add_response( $_mock_lwp->response_OK( $response ) );

    return;
}

=head2 set__payment_replacement__response_die

Set the response for payment_replacement method call to undef.
Which is treated as a die in method calls.

=cut

sub set__payment_replacement__response_die {
    my $self = shift;

    return $_mock_lwp->add_response($_mock_lwp->response_INTERNAL_SERVER_ERROR());
}


sub is_mocked {
    return 1;
}

sub _add_reference {
    my ( $hash ) = @_;

    $hash->{reference} = Data::UUID->new->create_str;
    return $hash;

}

BEGIN {

    # Set defaults
    set__create_new_payment_session__response__success();
    set__get_card_details_status__response__success();
    set__preauth_with_payment_session__response__success();

}

1;

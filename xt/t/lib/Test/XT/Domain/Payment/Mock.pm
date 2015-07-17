package Test::XT::Domain::Payment::Mock;

use NAP::policy 'tt','test';
use Moose;

# Be warned that XT::Domain::Payment uses MooseX::SemiAddordanceAccessor
# and consequently attribute readers are forced to be the attribute_name
# while writers are forced to be set_attribute_name (obviously
# attribute_name is the nane of the attribute).
extends 'XT::Domain::Payment';

use Moose::Util::TypeConstraints;
class_type 'DateTime';

use XTracker::Constants::Payment qw( :psp_return_codes );
use Test::XTracker::Mock::LWP;

use JSON;
use DateTime;
use DateTime::Duration;
use Data::UUID;

=head1 NAME

Test::XT::Domain::Payment::Mock - a class to mock PSP calls as made through
XT::Domain::Payment.

=head1 SYNOPSIS

    BEGIN {
        use_ok( Test::XT::Domain::Payment::Mock );
    }

    my $mock_xdp = Test::XT::Domain::Payment::Mock->new();

    isa_ok( $mock_xdp, "XT::Domain::Payment::Mock" );

    my $init_ref = $mock_xdp->init_with_payment_session( {
        'channel' => 'NAP-XT-INTL',
        'distributionCentre' => 'NAP-DC1',
        'paymentMethod' => 'CREDITCARD',
        'currency' => 'GBP',
        ...
    } );

    ok( $init_ref, "I have a response from init_with_payment_session" );
    ...

=head1 DESCRIPTION

This class provides a way to mocks calls to the PSP through
XT::Domain::Payment for tests.

All of the public methods of XT::Domain::Payment can be called via this
class. For each method called via this mock class the appropriate PSP
response will be loaded into a mocked LWP::UserAgent::request. That
response can optionally be configured as documented below or a standard
one will be provided, as documented.

This class functions by overloading the existing XT::Domain::Payment class
methods to set the appropriate response and then calling super() to pass
the request to the production code.

=head1 METHODS

=head2 new

    my $mock_xdp = Test::XT::Domain::Payments::Mock->new( {
        initialise_only => 1,
        overloaded_methods => [ qw( init_with_payment_session ... ) ],
        required_params => {
            init_with_payment_session => [ qw( required input parameters) ],
        },
    } );

Initialises an instance of the mock object. May be called without any
parameters or an optional hashref of optional parameters as follows:

=over 4

=item * initialise_only

By default this class will pass method calls through to the real
XT::Domain::Payment after loading the mocked PSP response into the
LWP::UserAgent request method so that the real code is properly tested.

This option stops the call through to the real XT::Domain::Payment and
should be called where you are testing code that calls XT::Domain::Payment
further down the stack. When this setting is enabled you need to make
the call to the mocked object as if you were calling XT::Domain::Payment
directly as this will load the appropriate response into the mocked LWP
layer.

=item * overloaded_methods

An array reference containing a list of the methods to be overloaded.
By default all public methods are overloaded.

=item * required_params

A hashref of required parameters for calls to XT::Domain::Payment.
The keys are the method names the value for each is an array ref listing
the required input parameters.

=back

=cut

has initialise_only => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 0,
);

has overloaded_methods => (
    is          => 'ro',
    isa         => 'ArrayRef',
    traits      => ['Array'],
    default     => sub {
        return [ qw(
            init_with_payment_session
            preauth_with_payment_session
            settle_payment
            refund_payment
            cancel_preauth
            getinfo_payment
            getorder_numbers
            getcustomer_saved_cards
            save_card
            get_new_card_token
            ) ];
    },
    handles     => {
        all_overloaded_methods  => 'elements',
    },
);

has mock_lwp => (
    is          => 'ro',
    isa         => 'Test::XTracker::Mock::LWP',
    init_arg    => undef,
    default     => sub {
        return Test::XTracker::Mock::LWP->new();
    },
);

has json    => (
    is          => 'ro',
    isa         => 'JSON',
    init_arg    => undef,
    default     => sub {
        return JSON->new->allow_nonref->utf8;
    },
);

has current_method => (
    is          => 'rw',
    isa         => 'Str|Undef',
    init_arg    => undef,
);

has input_params => (
    is          => 'rw',
    isa         => 'HashRef|Str|Undef',
    init_arg    => undef,
);

has input_validation => (
    is          => 'ro',
    isa         => 'HashRef',
    init_arg    => undef,
    default     => sub {
        return {
            init_with_payment_session    => {
                channel => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A[[:alnum]]{32}\z',
                },
                distributionCentre  => {
                    required    => 1,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:alnum]]{32}\z',
                },
                billingCountry  => {
                    required    => 1,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:alnum]]{32}\z',
                },
                paymentMethod   => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A(CREDITCARD|)\z',
                },
                coinAmount      => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A\d+\z',
                },
                isPreOrder      => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'bool',
                },
                cardNumber      => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'sub',
                    type_sub    => '_validate_card_number',
                },
                cardExpiryMonth => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'sub',
                    type_sub    => '_validate_card_expiry_month',
                },
                cardExpiryYear  => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'sub',
                    type_sub    => '_validate_card_expiry_year',
                },
                cardIssueNumber => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A\d+\z',
                },
                cardCVSNumber   => {
                    required    => 0,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A\d{3}\z',
                },
                cardType        => {
                    required    => 0,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A(VISA|ELECTRON|AMEX|MASTERCARD|MAESTRO|JCB|DELTA)\z',
                },
                isSavedCard     => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'bool',
                },
                currency        => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:alpha]]{3}\z',
                },
                title           => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:print]]{1,16}\z',
                },
                firstname       => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:print]]{1,128}\z',
                },
                lastname        => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:print]]{1,128}\z',
                },
                address1        => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:print]]{1,128}\z',
                },
                address2        => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:print]]{1,128}\z',
                },
                address3        => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:print]]{1,128}\z',
                },
                address4        => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:print]]{1,128}\z',
                },
                postcode        => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:print]]{1,128}\z',
                },
                merchantUrl     => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'sub',
                    type_sub    => '_validate_url',
                    max_length  => 128,
                },
                email           => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'sub',
                    type_sub    => '_validate_email',
                    max_length  => 128,
                },
                securePaymentToken  => {
                    required    => 0,
                    can_be_null => 1,
                    type        => 'regex',
                    type_regex  => '\A[[:alnum]]{32}\z',
                },
            },
            preauth_with_payment_session => {
                reference   => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A\d+\z',
                },
                orderNumber     => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A[[:alnum]]{36}\z',
                },
                cardNumber      => {
                    required    => 1,
                    type        => 'sub',
                    type_sub    => '_validate_card_number',
                    can_be_null => 1,
                },
                cardCVSNumber   => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A\d{3}\z',
                },
                providerReference   => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A\d{1,100}\z',
                },
                authcode   => {
                    required    => 0,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A[[:alnum]]{1,128}\z',
                },
                cv2AvsStatus    => {
                    required    => 0,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A(NO DATA MATCHES|ADDRESS MATCH ONLY|SECURITY CODE MATCH ONLY|ALL MATCH|DATA NOT CHECKED)\z',
                },
            },
            settle_payment  => {
                channel => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A[[:alnum]]{32}\z',
                },
                reference   => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'digit',
                },
                coinAmount => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'digit',
                },
            },
            refund_payment  => {
                channel => {
                    required    => 1,
                    max_length  => 32,
                    can_be_null => 0,
                    type        => 'alnum',
                },
                reference   => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'digit',
                },
                coinAmount => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'digit',
                },
            },
            cancel_preauth  => {
                reference   => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'digit',
                },
            },
            getinfo_payment => {
                reference   => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'digit',
                },
            },
            getorder_numbers    => {
                initialReferences => {
                    string => {
                        required    => 1,
                        can_be_null => 0,
                        type        => 'ARRAY',
                    },
                },
            },
            getcustomer_saved_cards => {
                site    => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'set',
                    type_set    => 'nap_intl|nap_am|nap_apac|outnet_intl|outnet_am|outnet_apac|mrp_intl|mrp_am|mrp_apac|nap_test|mrp_test|outnet_test|PSP_SecMod',
                },
                userID  => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'digit',
                },
                customerID      => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'digit',
                },
                customerCardToken => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'alnum',
                },
                admin => {
                    required    => 0,
                    can_be_null => 0,
                    type        => 'bool',
                },
            },
            save_card => {
                cardToken       => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A\[[:alnum:]]+\z',
                },
                cardType        => {
                    required    => 0,
                    can_be_null => 0,
                    type        => 'regex',
                    type_set    => '\A(VISA|ELECTRON|AMEX|MASTERCARD|MAESTRO|JCB|DELTA)\z',
                },
                customerID      => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A\d+\z',
                },
                last4Digits     => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A\d{4}\z',
                },
                expiryDate => {
                    required    => 1,
                    can_be_null => 0,
                    type        => 'regex',
                    type_regex  => '\A\d{2}\/\d{2}\z',
                }
            },
        };
    },
);

has required_params => (
    is          => 'rw',
    isa         => 'HashRef[ArrayRef]',
    default     => sub {
        return {
            init_with_payment_session    => [ qw(
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
                )
            ],
            preauth_with_payment_session => [ qw(
                paymentSessionId
                reference
                orderNumber
                )
            ],
            settle_payment  => [ qw(
                channel
                coinAmount
                preAuthReference
                )
            ],
            refund_payment   => [ qw(
                reference
                coinAmount
                channel
                )
            ],
            cancel_preauth   => ['preAuthReference'],
            getinfo_payment  => [ 'reference' ],
            getorder_numbers => [ ],
            getcustomer_saved_cards => [ qw(
                site
                userID
                customerID
                cardToken
                )
            ],
            save_card => [ qw(
                site
                userID
                creditCardReadOnly
                customerID
                cardToken
                )
            ],
            get_new_card_token => [ ],
        };
    },
);

=head2  set_return_code

Sets the return code to be returned by the next request to the PSP.

=cut

has return_code => (
    is          => 'rw',
    isa         => 'Int|Str|Undef',
    default     => sub { return $PSP_RETURN_CODE__SUCCESS },
    required    => 0,
);

=head2 set_reference

Sets the reference to be returned by the next request to the PSP.

=cut

has reference   => (
    is          => 'rw',
    isa         => 'Int|Str|Undef',
    default     => sub { return int(rand(12345)); },
    required    => 0,
);

=head2 set_return_code_reason

Sets the return code reason value to be returned by the PSP.

=cut

has return_code_reason => (
    is          => 'rw',
    isa         => 'Str|Undef',
    required    => 0
);

=head2 set_cv2avs_status

Sets the cv2avs status to be returned by the PSP. Defaults to "ALL MATCH".

=cut

has cv2avs_status => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => sub { return "ALL MATCH"; },
);

=head2 set_psp_provider

Sets the PSP provider value returned by the PSP. Defaults to "test-psp".

=cut

has psp_provider => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => sub {
        return "test-psp";
    }
);

=head2 set_psp_extra_reason

Sets the extra reason value returned by the PSP.

=cut

has psp_extra_reason => (
    is          => 'rw',
    isa         => 'Int|Str|Undef',
    default     => sub { return undef; },
);

=head2 set_psp_acs_url

Sets the acsurl value returned by the PSP.

=cut

has psp_acs_url => (
    is          => 'rw',
    isa         => 'Int|Str|Undef',
    default     => sub { return undef; },
);

=head2 set_psp_pareq

Sets the pareq value returned by the PSP.

=cut

has psp_pareq => (
    is          => 'rw',
    isa         => 'Str|Int|Undef',
    default     => sub { return undef; },
);

=head2 set_psp_auth_code

Sets the auth code returned by the PSP. Defaults to a random integer.

=cut

has psp_auth_code => (
    is          => 'rw',
    isa         => 'Int|Str|Undef',
    default     => sub { return int(rand(12345)); },
);

=head2 set_customer_id

Sets the customer id value returned by the PSP.

=cut

has customer_id => (
    is          => 'rw',
    isa         => 'Int|Str|Undef',
    default     => '110000009',
);

=head2 set_coin_amonut

Sets the coin amount returned by the PSP.

=cut

has coin_amount => (
    is          => 'rw',
    isa         => 'Int|Undef',
    default     => 123456,
);

=head2 set_card_type

Sets the card type returned by the PSP.

=cut

has card_type => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'DisasterCard',
);

=head2 set_card_number

Sets the full card number to be returned by the PSP.

IMPORTANT - Setting this will also update the following
attributes:

card_first_digit
card_last_four_digits

=cut

has card_number => (
    is          => 'rw',
    isa         => 'Int|Undef',
    default     => 0,
    trigger     => sub {
        my $self = shift;
        my ( $value ) = @_;

        $self->card_first_digit( substr $value, 0, 1 );
        $self->card_last_four_digits( substr $value, -4 );
    },
);

=head2 set_card_first_digit

Sets the first digit of the card to be returned by the PSP.

=cut

has card_first_digit => (
    is          => 'rw',
    isa         => 'Int|Undef',
    default     => 6,
);

=head2 set_card_last_four_digits

Sets the first digit of the card to be returned by the PSP.

=cut

has card_last_four_digits => (
    is          => 'rw',
    isa         => 'Int|Undef',
    default     => 6667,
);

=head2 set_card_issue_number

Sets the card issue number to be returned by the PSP.

=cut

has card_issue_number => (
    is          => 'rw',
    isa         => 'Int|Undef',
    default     => 1,
);

=head2 set_address_1

Sets the first line of the address to be returned by the PSP.

=cut

has address_1 => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => '4-4-1-SomeAddress1',
);

=head2 set_address_2

Sets the second line of the address to be returned by the PSP.

=cut

has address_2 => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => '4-4-1-SomeAddress2',
);

=head2 set_address_3

Sets the third line of the address to be returned by the PSP.

=cut

has address_3 => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => '',
);

=head2 set_address_4

Sets the fourth line of the address to be returned by the PSP.

=cut

has address_4 => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => '',
);

=head2 set_billing_country

Sets the billing country to be returned by the PSP.

=cut

has billing_country => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'GB',
);

=head2 set_card_expiry_date

Sets the card expiry date to be returned by the PSP.

=cut

has card_expiry_date => (
    is          => 'rw',
    isa         => 'DateTime|Undef',
    default     => sub{ DateTime->now->add( months => 3 ) },
);

=head2 set_card_start_date

Sets the card start date to be returned by the PSP.

=cut

has card_start_date => (
    is          => 'rw',
    isa         => 'DateTime|Undef',
    default     => sub{ DateTime->now->subtract( years => 2 ) },
);

=head2 set_currency

Sets the currency to be returned by the PSP.

=cut

has currency => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'GBP',
);

=head2 set_billing_country

Sets the billing country to be returned by the PSP.

=cut

has billing_country => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'GB',
);

=head2 set_postcode

Sets the postcode to be returned by the PSP.

=cut

has postcode => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'W12 7GF',
);

=head2 set_email_address

Sets the email address to be returned by the PSP.

=cut

has email_address => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'dev4-4-1@net-a-porter.com',
);

=head2 set_title

Sets the title to be returned by the PSP.

=cut

has title => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'Mr',
);

=head2 set_first_name

Sets the first name to be returned by the PSP.

=cut

has first_name => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'Oliver',
);

=head2 set_last_name

Sets the last name to be returned by the PSP.

=cut

has last_name => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'Victor-Smith',
);

=head2 set_is_new_card

Sets whether the card is defined as new when returned by the PSP.

=cut

has is_new_card => (
    is          => 'rw',
    isa         => 'Bool|Undef',
    default     => 0,
);

=head2 set_preauth_internal_reference

Sets the preauth internal reference returned by the PSP.

=cut

has preauth_internal_reference => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => '123456789',
);

=head2 set_secure_response_3d

Sets the 3D secure response returned by the PSP.

=cut

has secure_response_3d => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => '3DRESPONSE',
);

=head2 set_card_history

Sets the card history returned by the PSP.

=cut

has card_history => (
    is          => 'rw',
    isa         => 'ArrayRef|Undef',
    default     => sub { [] },
);

=head2 set_card_history_is_stored_card

Sets the card history stored card value returned by the PSP.

=cut

has card_history_is_stored_card => (
    is          => 'rw',
    isa         => 'Bool|Undef',
    default     => 0,
);

=head2 set_card_history_date

Sets the card history date returned by the PSP.

=cut

has card_history_date => (
    is          => 'rw',
    isa         => 'DateTime|Undef',
    default     => sub{ DateTime->now->subtract( months => 1 ) },
);

=head2 set_card_history_order_number

Sets the card history order number returned by the PSP.

=cut

has card_history_order_number => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => sub{ Data::UUID->new->create_str },
);

=head2 set_card_history_sucess

Sets the card history success returned by the PSP.

=cut

has card_history_sucess => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'Card History Succes',
);

=head2 set_card_history_preauth_internal_reason

Sets the card history pre-auth internal reason returned by the PSP.

=cut

has card_history_preauth_internal_reason => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'Pre-Auth Internal Reason',
);

=head2 set_card_history_preauth_provider_reason

Sets the card history returned by the PSP.

=cut

has card_history_preauth_provider_reason => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'Pre-Auth Provider Reason',
);

=head2 set_card_history_preauth_provider_return_code

Sets the card history Pre-Auth provider return code returned by the PSP.

=cut

has card_history_preauth_provider_return_code => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'PREAUTHPROVRETCOD',
);

=head2 set_card_history_settlement_reason

Sets the card history settlement reason returned by the PSP.

=cut

has card_history_settlement_reason  => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => 'Card History Settlement Reason',
);

=head2 set_card_history_settlement_success

Sets the card history settlement reason returned by the PSP.

=cut

has card_history_settlement_success  => (
    is          => 'rw',
    isa         => 'Bool|Undef',
    default     => 1,
);

=head2 set_new_card_token

Sets the new card token returned by the PSP.

=cut

has new_card_token  => (
    is          => 'rw',
    isa         => 'Str|Undef',
    default     => '7772236b33c6b612ccfc9643099e6e133b25d229bc6045ade97b27844aa2ff97',
);

=head2 set_psp_saved_cards

Set a list of saved cards to be returned by the PSP. These must be an
array reference containing a list of hash references as follows:

[
    {
        cardType  => 'VISA',
        last4Digits => '1110',
        expiryDate => '01/16',
        customerId => '110000009'
    }
]

=cut

has psp_saved_cards => (
    is          => 'rw',
    isa         => 'ArrayRef[HashRef]',
    lazy        => 1,
    builder     => '_build_psp_saved_cards',
);

sub _build_psp_saved_cards {
    my $self = shift;

    my $date        = DateTime->now();
    my $start_date  = $date->subtract( months => 3 );
    my $expiry_date = $date->add( months => 3 );

    my %fake_cards = (
        VISA => {
            cardNumber  => '4111111111111110',
            last4Digits => '1110',
        },
        MASTERCARD => {
            cardNumber  => '5105105105105100',
            last4Digits => '5100',
        },
        ELECTRON => {
            cardNumber  => '4917300000000008',
            last4Digits => '0008',
        },
    );

    my $response = [];
    foreach my $card_type ( keys %fake_cards ) {
        push @$response, {
            # This format for timestamp will spit out something like:
            #   2013-12-16T09:46:53.000+0000
            timestamp       => $date->strftime('%FT%T.%3N%z'),
            cardType        => $card_type,
            last4Digits     => $fake_cards{$card_type}->{last4Digits},
            cardHolderName  => $self->first_name // 'Some Customer',
            issueNumber     => $self->card_issue_number // '',
            expiryDate      => $expiry_date->strftime("%m/%y"),
            startDate       => $start_date->strftime("%m/%y"),
        };
    }
    return $response;
}

=head2 set_psp_card_details

Set details for a saved card. Value is a hashref. See PSP documentation
for details.

=cut

has psp_card_details => (
    is          => 'rw',
    isa         => 'HashRef',
    lazy        => 1,
    builder     => '_build_psp_card_details',
);

sub _build_psp_card_details {
    my $self = shift;

    if ( defined $self->input_params && $self->input_params->{creditCardReadOnlyBasic} ) {
        my $input_card = $self->input_params->{creditCardReadOnlyBasic};
        foreach my $card ( @{$self->psp_saved_cards} ) {
            next unless ( $card->{customerId} eq $input_card->{customerId} &&
                          $card->{cardType} eq $input_card->{cardType} &&
                          $card->{last4Digits} eq $input_card->{last4Digits}
                        );

            # Add the rest of the data
            $card->{cardHoldersName} //= join( ' ', $self->title, $self->first_name, $self->last_name );
            $card->{cardNumber}      //= $self->card_number;
            $card->{issueNumber}     //= $self->card_issue_number;
            $card->{startDate}       //= $self->card_start_date->strftime( '%m/%y' );
            $card->{expiryDate}      //= $self->card_expiry_date->strftime( '%m/%y' );

            return $card;
        }
    }

    # We don't have a matching saved card so set the appropriate mock LWP
    # response and return an empty hashref;
    $self->mock_lwp->add_response( $self->mock_lwp->response_BAD_REQUEST() );
    return { };
}

sub response {
    my $self = shift;

    # This is a simple switch statement setting the relevant response per
    # the documentation for the PSP.

    SMARTMATCH:
    use experimental 'smartmatch';
    given ( $self->current_method ) {
        when ('init_with_payment_session') {
            return {
                returnCodeResult    => $self->return_code // $PSP_RETURN_CODE__3D_SECURE_BYPASSED,
                reference           => $self->reference,
                returnCodeReason    => $self->return_code_reason // "3DSecure is not supported",
                provider            => $self->psp_provider,
                extraReason         => $self->psp_extra_reason,
                acsUrl              => $self->psp_acs_url,
                pareq               => $self->psp_pareq,
            };
        }
        when ('preauth_with_payment_session') {
            return {
                returnCodeResult    => $self->return_code // $PSP_RETURN_CODE__SUCCESS,
                reference           => $self->reference,
                returnCodeReason    => $self->return_code_reason // "Success",
                extraReason         => $self->psp_extra_reason // "ACCEPTED",
                provider            => $self->psp_provider,
                authCode            => $self->psp_auth_code,
                cv2AvsStatus        => $self->cv2avs_status
            };
        }
        when ('settle_payment') {
            return {
                reference           => $self->reference,
                returnCodeResult    => $self->return_code // $PSP_RETURN_CODE__SUCCESS,
                returnCodeReason    => $self->return_code_reason // "Success",
                extraReason         => $self->psp_extra_reason // "FULFILLED OK",
                provider            => $self->psp_provider
            };
        }
        when ('cancel_preauth') {
            return {
                reference           => $self->reference,
                returnCodeResult    => $self->return_code // $PSP_RETURN_CODE__SUCCESS,
                returnCodeReason    => $self->return_code_reason // "Success",
                extraReason         => $self->psp_extra_reason // "CANCELLED OK",
                provider            => $self->psp_provider
            };
        }
        when ('refund_payment') {
            return {
                reference           => $self->reference,
                returnCodeResult    => $self->return_code // $PSP_RETURN_CODE__SUCCESS,
                returnCodeReason    => $self->return_code_reason // "Success",
                extraReason         => $self->psp_extra_reason // "ACCEPTED",
                provider            => $self->psp_provider
            };
        }
        when ('getinfo_payment') {
            return {
                paymentMethod               => 'CREDITCARD',
                address1                    => $self->address_1,
                address2                    => $self->address_2,
                address3                    => $self->address_3,
                address4                    => $self->address_4,
                authCode                    => $self->psp_auth_code,
                billingCountry              => $self->billing_country,
                cardInfo                    => {
                    cardExpiryMonth             => $self->card_expiry_date->strftime( '%m' ),
                    cardExpiryYear              => $self->card_expiry_date->strftime( '%y' ),
                    cardNumberFirstDigit        => $self->card_first_digit // '6',
                    cardNumberLastFourDigits    => $self->card_last_four_digits // '6667',
                    cardType                    => $self->card_type // 'DisasterCard',
                    newCard                     => $self->is_new_card,
                },
                coinAmount                  => $self->coin_amount // 123456,
                currency                    => $self->currency,
                cv2avsStatus                => $self->cv2avs_status // 'ALL MATCH',
                email                       => $self->email_address,
                firstName                   => $self->first_name,
                lastName                    => $self->last_name,
                postcode                    => $self->postcode,
                preauthReference            => $self->preauth_internal_reference,
                provider                    => $self->psp_provider,
                providerReference           => $self->reference // 'CARROT',
                threeDSecureResponse        => $self->secure_response_3d,
                title                       => $self->title,
                paymentHistory              => [
                    cardInfo                => {
                        cardNumberFirstDigit        => $self->card_first_digit // '6',
                        cardNumberLastFourDigits    => $self->card_last_four_digits // '6667',
                        storedCard                  => $self->card_history_is_stored_card,
                    },
                    currency                        => $self->currency,
                    cv2avsStatus                    => $self->cv2avs_status // 'ALL MATCH',
                    date                            => $self->card_history_date->strftime( '%c' ),
                    orderNumber                     => $self->card_history_order_number,
                    preAuthInternalReason           => $self->card_history_preauth_internal_reason,
                    preAuthProviderReason           => $self->card_history_preauth_provider_reason,
                    preAuthProviderReturnCode       => $self->card_history_preauth_provider_return_code,
                    preAuthReference                => $self->reference,
                    success                         => $self->card_history_sucess,
                    settlement                      => [
                        settleReference      => $self->reference,
                        settlementCoinAmount => $self->coin_amount,
                        settlementReason     => $self->card_history_settlement_reason ,
                        success              => $self->card_history_settlement_success,
                    ],
                ],
            };
        }
        when ('getorder_numbers') {
            my $response = {};
            my $ref = 0;
            foreach my $reference ( @{$self->input_params->{initialReferences}->{string}} ) {
                my ($internal_reference, $timestamp) = split(/-/, $reference);

                $response->{$internal_reference} = defined $timestamp ?
                    $timestamp
                    : "Invalid reference: Internal reference '$reference' is not in a valid format.";
            }

            return $response;
        }
        when ('getcustomer_saved_cards') {
            return $self->psp_saved_cards;
        }
        when ('save_card') {
            return undef;
        }
        when ( 'get_new_card_token' ) {
            return {
                customerCardToken => $self->new_card_token,
                message           => undef,
                error             => undef,
            }
        }
        default {
            warn "Unknown Method";
        }
    }
}

sub BUILD {
    my $class = shift;

    foreach my $method ( $class->all_overloaded_methods ) {
        override $method => sub {
            my ($self, $input) = @_;

            # Enable LWP mocking
            $class->mock_lwp->enabled(1);
            $class->set_current_method( $method );
            $class->set_input_params( $input );

            my $response = {};

            # Check for required parameters
            foreach my $required_param ( @{ $self->required_params->{$method} } ) {
                unless ( defined $input->{$required_param} ) {
                    $response->{returnCodeResult} = $PSP_RETURN_CODE__MISSING_INFO;
                }
            }
            # returnCodeResult will only be defined if we have missing data
            if ( defined $response->{returnCodeResult} ) {
                # Different PSP calls return different things for validation errors
                SMARTMATCH:
                use experimental 'smartmatch';
                given ( $method ) {
                    when ('init_with_payment_session') {
                        $class->mock_lwp->add_response( $class->mock_lwp->response_INTERNAL_SERVER_ERROR() );
                    }
                    when ('getorder_numbers') {
                        $class->mock_lwp->add_response( $class->mock_lwp->response_NOT_FOUND() );
                    }
                    when ('getcustomer_saved_cards') {
                        $class->mock_lwp->add_response( $class->mock_lwp->response_BAD_REQUEST( [] ) );;
                    }
                    when ('save_card') {
                        $class->mock_lwp->add_response( $class->mock_lwp->response_BAD_REQUEST( {
                            message => "Please check your input and try again.",
                            error => "Invalid Details"
                        } ) );
                    }
                    when ( 'getinfo_payment' ) {
                        return {};
                    }
                    default {
                        $response->{returnCodeReason} = "The request contains missing and/or incorrect data";
                        $response->{extraReason} = "Historical transaction reference is required";
                        $response->{provider} = undef;
                        $response->{reference} = undef;

                        foreach my $reference ( qw( InitReference
                                                    preAuthReference
                                                    SettlementReference
                                                  ) ) {
                            if ( defined $input->{$reference} ) {
                                $response->{extraReason} = 'No historical data could be found for reference '.$input->{reference};
                            }
                        }
                        $class->mock_lwp->add_response( $class->mock_lwp->response_OK( $self->json->encode( $response ) ) );
                    }
                }
            }
            else {
                # We should have all required parameters so let's go ahead
                # and build up the correct response.

                $class->_get_reference($input);

                $class->mock_lwp->add_response(
                    $class->mock_lwp->response_OK(
                        $self->json->encode( $class->response() )
                    )
                );
            }

            # Call XT::Domain::Payment->$method for real
            return super() unless $self->initialise_only;
        };
    }
}

sub DEMOLISH {
    my $self = shift;
    my $global_destruction = shift;

    return if $global_destruction;

    $self->mock_lwp->enabled(0);
}

sub _get_reference {
    my ($self, $input) = @_;

    return unless $input && ref $input eq 'HASH';
    foreach my $reference ( qw( InitReference
                                preAuthReference
                                SettlementReference
                              ) ) {
        if ( defined $input->{$reference} ) {
            $self->set_reference($input->{$reference});
        }
    }
}

=head2 with_mock_lwp

Execute code with LWP mocking temporarily enabled.

Accepts one parameter, which must be a CodeRef.

This will turn on LWP mocking by calling C<$domain->mock_lwp->enabled(1)>,
execute the given code reference and then restore the LWP mocking state.

    # .. Some code that a mocked LWP would break.
    $domain->with_mock_lwp( sub {
        # .. some code here ..
    } );
    # .. Some more code that a mocked LWP would break.

=cut

sub with_mock_lwp {
    my ($self,  $code ) = @_;

    if ( ref( $code ) eq 'CODE' ) {

        my $original = $self->mock_lwp->enabled;

        $self->mock_lwp->enabled( 1 );
        $code->();
        $self->mock_lwp->enabled( $original );

    } else {

        die "You must pass a CodeRef to with_mock_lwp";

    }

}

=head1 EXAMPLE USAGE

use strict;
use warnings;

use XT::Domain::Payment;

use Test::XT::Domain::Payment::Mock;

use Data::Printer;

my $xtd = XT::Domain::Payment->new();

my $dp = Test::XT::Domain::Payment::Mock->new({ initialise_only => 1} );

$dp->getcustomer_saved_cards( {
    site    => 'nap',
    userID  => 11,
    customerID  => '1223132',
    cardToken   => 'asdfa1234133'
} );

my $cards = $xtd->getcustomer_saved_cards( {
    site    => 'nap',
    userID  => 11,
    customerID  => '1223132',
    cardToken   => 'asdfa1234133'
} );

warn p($cards);

my @customer_cards;

foreach my $card ( @$cards ) {
    $card->populate_extended_attributes();
}

warn p($cards);


=cut

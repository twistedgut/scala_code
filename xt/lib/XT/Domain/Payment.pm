package XT::Domain::Payment;

use NAP::policy qw/class tt/;
use Class::MOP::Method;
use MooseX::SemiAffordanceAccessor;

use Storable    qw( dclone );

use XTracker::Config::Local qw( config_var );
use XTracker::Logfile qw(xt_logger);

use XT::Net::PaymentService::Client;
use XT::Domain::Payment::Form;
use XT::Address;

use Carp;
use Scalar::Util    qw( blessed );

# ACL: Protect method calls
with 'XT::AccessControls::Role::ProtectMethodCall' => {
    protect => {
        getinfo_payment => {
            roles               => [ qw ( app_canViewOrderPaymentDetails )],
            return_if_no_access => { },
        }
    }
};

=head1 NAME

XT::Domain::Payment

=head1 DESCRIPTION

Domain class containing payment business logic. XT will use our internal
Payment Service as a mediator of any interactions with third party payment
service providers (PSPs). The internal NAP Payment Service acts as a proxy to
these external PSPs, providing a normalised web service interface to common
PSP functions such as pre-authorisations and settlements. This domain class is
mainly a wrapper which delegates to the corresponding call in either the SOAP
or HTTP interface of the NAP Payment Service. Currently our external PSP
partners are DataCash and Chase Paymentech. Integration and communication
details of exchanging information with these PSPs is encapsulated within the
NAP Payment Service.

=head1 ATTRIBUTES

=head2 http_client

The HTTP interface client class

=cut

has http_client => (
    is      => 'ro',
    default => sub {
        return XT::Net::PaymentService::Client->new();
    },
);


=head2 logger

=cut

has logger => (
    is      => 'ro',
    default => sub { xt_logger },
);


=head2 acl

XT::AccessControls object

=cut

has acl => (
    is          => 'ro',
    isa         => 'XT::AccessControls',
    required    => 0,

);

=head1 METHODS

=head2 shift_dp

Helper method to move the decimal place of the amount as appropriate

=cut

sub shift_dp {
    my($self,$value,$multiplier) = @_;

    if ($value =~ /^\d*\.(\d+)$/) {
        my $end = $1;

        my $factor = (defined $multiplier)
            ? $multiplier : "1" . '0' x length $end;

        return $value * $factor;
    }

    return $value;
}

=head2 settle_payment

Settle an existing authorisation for a defined amount. Parameter must be a
hashref of the form:

    { channel    => 'channel-str',  # The client channel as defined by conf
      coinAmount => 100000,         # Amount of money to settle
      preAuthReference => 'ref-str' # Reference returned by a previous preauth
    }

If the amount to settle does not exactly match the amount pre-authorised this
can cause problems with some payment service providers. The rules around this
are PSP specific.

Note: The coinAmount field is always in the lowest denomination for the
particular currency.

=cut

sub settle_payment {
    my($self, $data) = @_;

    my $response = {};
    try{
        # SOAP-style name conversions
        if($data->{preAuthReference}){
            $data->{reference} = delete $data->{preAuthReference};
        }

        my $result = $self->http_client->settle_payment($data);

        # Wrap response in SOAP-style first level
        $response->{SettleResponse} = $result;
    }
    catch {
        # Just log the error - response will be an empty hashref which is what
        # the current module client code is expecting (sort of)
        $self->logger->warn($_);
    };

    return $response;
}

=head2 refund_payment

Refund a defined amount to a specific card used for a previous
settlement. Parameter must be a hashref of the form:

    { channel    => 'channel-str',     # The client channel as defined by conf
      coinAmount => 100000,            # Amount of money to refund
      settlementReference => 'ref-str' # Reference returned by a settlement
    }

Note: The coinAmount field is always in the lowest denomination for the
particular currency.

=cut

sub refund_payment {
    my($self, $data) = @_;

    if ( exists $data->{refundItems} ) {

        # The refundItems key must be an ArrayRef.
        croak 'Parameter "refundItems" passed to refund_payment is not an ArrayRef'
            unless ref( $data->{refundItems} ) eq 'ARRAY';

        # Remove the refundItems key if there are no records in it.
        delete $data->{refundItems}
            unless @{ $data->{refundItems} };

    }

    my $response = {};
    try{
        # SOAP-style name conversions
        if($data->{settlementReference}){
            $data->{reference} = delete $data->{settlementReference};
        }

        my $result = $self->http_client->refund_payment($data);

        # Wrap response in SOAP-style first level
        $response->{RefundResponse} = $result;
    }
    catch {
        # Just log the error - response will be an empty hashref which is what
        # the current module client code is expecting (sort of)
        $self->logger->warn($_);
    };

    return $response;
}

=head2 cancel_preauth

Cancel a previously requested preauth, releasing the reservation of funds from
the card. Parameter must be a hashref of the form:

    {
       preAuthReference => 'ref-str' # Reference returned by a preauth
    }

=cut

sub cancel_preauth {
    my($self, $data) = @_;

    my $response = {};
    try{
        # SOAP-style name conversions
        if($data->{preAuthReference}){
            $data->{reference} = delete $data->{preAuthReference};
        }

        my $result = $self->http_client->cancel_preauth($data);

        # Wrap response in SOAP-style first level
        $response->{CancelResponse} = $result;
    }
    catch {
        # Just log the error - response will be an empty hashref which is what
        # the current module client code is expecting (sort of)
        $self->logger->warn($_);
    };

    return $response;
}

=head2 getinfo_payment

Request the payment information for a specific preauth. This also returns the
entire transaction history for the card used in the requested
preauth. Parameter must be a hashref of the form:

    {
       reference => 'ref-str' # Reference returned by a preauth
    }

=cut

sub getinfo_payment {
    my($self, $data) = @_;

    my $response = {};
    try{
        my $result = $self->http_client->getinfo_payment($data);

        if (defined $result->{PaymentInfoResponse}) {
            $response = $result->{PaymentInfoResponse};
        }
        else {
            $response = $result;
        }

        # if received the response in the format used by the old
        # 'payment-info' serivce then turn it into the new format
        $response = $self->_parse_getinfo_payment_response( $response );

        # Further processing of the CV2 status field expects this field to
        # have a defined value but the new HTTP API may return null (undef) in
        # cases where there is no value in the service. For now normalise this
        # to the string 'NIL', which is the value returned by the previous
        # SOAP API (via XML::Compile). When we've removed the assumption of
        # defined-ness from all client code we can remove this.
        $response->{cv2avsStatus} //= 'NIL';
    }
    catch {
        $self->logger->warn($_);
    };

    return $response;
}

=head2 getorder_numbers

Given a structure containing an array of external PSP transaction references
return a hashref structure with the order numbers that correspond to those
transactions. Parameter must be an array ref containing the references:

    [ ref1, ref2, ref3 ... ]

=cut

sub getorder_numbers {
    my($self, $data) = @_;

    my $response = {};
    try{
        $response = $self->http_client->getorder_numbers($data);
    }
    catch {
        $self->logger->warn($_);
    };

    return $response;
}

=head2 getcustomer_saved_cards

Given a C<site>, C<userID>, C<customerID> and C<customerCardToken>, get all
the saved cards associated with that customer.

    my $payment = XT::Domain::Payment->new;
    $payment->getcustomer_saved_cards( {
        site                => 'nap',
        userID              => 11,
        customerID          => '110000002',
        customerCardToken   => '7772236b33c6b612ccfc9643099e6e133b25d229bc6045ade97b27844aa2ff97'
    } );

Returns an ArrayRef of HashRefs, for example:

    [
        {
            timestamp       => "2013-12-16T09:46:53.000+0000",
            cardType        => "MAESTRO",
            last4Digits     => 1,
            cardHolderName  => "Mrs Test Tester",
            issueNumber     => "3",
            expiryDate      => "03/19",
            startDate       => "03/13"
        }
    ]

=cut

sub getcustomer_saved_cards {
    my ( $self, $data ) = @_;

    my $response = [];

    try{

        # Make sure the boolean value 'admin' has been handled correctly.
        $self->_update_boolean_values( $data, 'admin' );

        # Make the call.
        my $result = $self->http_client->get_all_customer_cards( $data );

        if ( defined $result && ref( $result ) eq 'ARRAY' ) {
        # We should get an ArrayRef of HashRefs back.

            # Expand the Last Four Digits to be four digits, because the
            # service returns an integer.
            $_->{last4Digits} = sprintf( '%04d', $_->{last4Digits} )
                foreach @$result;

            $response = $result;

        }

    }

    catch {
        $self->logger->warn( $_ );
    };

    return $response;

}

=head2 save_card

Given a C<site>, C<userID>, C<customerID>, C<cardToken> and a HashRef C<creditCardReadOnly>,
save the card details to the associated customer. The key 'creditCardReadOnly' is the full
details of the card you want to save.

    my $payment = XT::Domain::Payment->new;
    $payment->save_card( {
        site   => 'nap',
        userID => 11,
        creditCardReadOnly => {
            cardToken       =>  '7772236b33c6b612ccfc9643099e6e133b25d229bc6045ade97b27844aa2ff97',
            customerId      => '110000009',
            expiryDate      => '03/16',
            cardType        => 'AMEX',
            last4Digits     => '0006',
            cardNumber      => '343434100000006',
            cardHoldersName => 'Mr O Victor-Smith',
        },
        customerID => '110000009',
        cardToken  =>  '7772236b33c6b612ccfc9643099e6e133b25d229bc6045ade97b27844aa2ff97',
    } );

=cut

sub save_card {
    my( $self, $data ) = @_;

    my $response = 0;

    try{

        # Make sure the boolean value 'admin' has been handled correctly.
        $self->_update_boolean_values( $data, 'admin' );

        # We're saving a customer card.
        $data->{userType} = 'customer';

        $self->http_client->save_card( $data );

        $response = 1;

    }

    catch {
        $self->logger->warn($_);
    };

    return $response;
}

=head2 get_new_card_token

Returns a new card token.

    my $payment = XT::Domain::Payment->new;
    my $result = $payment->get_card_token;
    my $token = $result->{token};

Returns a HashRef with only one key: token.

=cut

sub get_new_card_token {
    my $self = shift;

    my $result = {};

    try{

        $result = $self->http_client->get_new_customer_card_token;

    }

    catch {
        $self->logger->warn($_);
    };

    return $result;

}

=head2 amount_exceeds_provider_threshold

Used to find out if a new Order Value would take a Payment over its Threshold.

=cut

sub amount_exceeds_provider_threshold {
    my ( $self, $data ) = @_;

    my $result = {};

    try {
        $result = $self->http_client->amount_exceeds_provider_threshold( $data );
    }
    catch {
        $self->logger->warn( $_ );
    };

    return $result;
}

=head2 reauthorise_address

When a Shipping Address is changed this is used to update the PSP.

Currently only used for PayPal payments.

=cut

sub reauthorise_address {
    my ( $self, $args ) = @_;

    # check to see if the correct arguments have
    # been passed. Do this outside the Try Catch
    # so that it will die for XT reasons where as
    # inside the Try will die for Service reasons
    foreach my $arg ( qw( reference order_number customer_name address first_name last_name ) ) {
        croak "Argument '${arg}' Required for " . __PACKAGE__ . "->reauthorise_address"
                                unless ( $args->{ $arg } );
    }

    my $address = $args->{address};
    croak "'address' needs to be an Object for " . __PACKAGE__ . "->reauthorise_address"
                    unless ( blessed( $address ) );

    my $shipping_address = XT::Address->new( $address )
        ->apply_format('Country')
        ->apply_format('PSP');

    # set-up the data for the request
    my $data = {
        reference       => $args->{reference},
        orderNumber     => $args->{order_number},
        customerName    => $args->{customer_name},
        firstName       => $args->{first_name},
        lastName        => $args->{last_name},
        shippingAddress => $shipping_address->as_hashref,
    };

    my $result = {};
    try {
        $result = $self->http_client->reauthorise_address( $data );
    }
    catch {
        $self->logger->warn( $_ );
    };

    return $result;
}

=head2 create_new_payment_session

Returns a new payment session ID.

=cut

sub create_new_payment_session {
    my ( $self, $client_session_id, $card_token ) = @_;

    croak __PACKAGE__ . "::create_new_payment_session - Parameter 'client_session_id' is required"
        unless $client_session_id;

    croak __PACKAGE__ . "::create_new_payment_session - Parameter 'card_token' is required"
        unless $card_token;

    my $result;

    try {

        my $data = {
            clientSessionId     => $client_session_id,
            customerCardToken   => $card_token,
        };

        $result = $self->http_client->payment_session( $data );

        $result = $result->{paymentSessionId}
            if ref( $result ) eq 'HASH';

    }

    catch {
        my $error = $_;
        $self->logger->warn( __PACKAGE__ . "::create_new_payment_session - ERROR: $error" );
    };

    return $result;

}

=head2 get_card_details_status( $payment_session_id )

Takes a C<$payment_session_id> that has been returned from
C<create_payment_session> and returns the following data structure if
the transaction associated with the C<$payment_session_id> succeeded:

    {
        valid  => 1,
        errors => { }, # An empty HashRef
    }

Or this if the transaction failed:

    {
        valid  => 0,
        errors => {
            54007 => 'Card Number too long or too short',
            54008 => 'Invalid Card Number i.e failed luhn check',
        },
    }

The list of errors describe why the POST associated with the C<$payment_session_id> failed.

=cut

sub get_card_details_status {
    my ( $self, $payment_session_id ) = @_;

    my $result = {};

    try {

        # At the time of writing, the Session ID must be a 32 character
        # alphanumeric string. We won't do any validation here, because if
        # the PSP where to change this, XTracker would break and we would
        # have to update it. But we can at least check we have something
        # sensible first.

        die __PACKAGE__ . '::get_card_details_status - $payment_session_id must be defined'
            unless $payment_session_id;

        $result = $self->http_client->get_card_details_status( {
            paymentSessionId => $payment_session_id,
        } );

        # Remove the original list of error codes from the reuslt.
        my $error_codes   = delete $result->{errorCodes};
        $result->{errors} = {};

        # If we got some errors, expand them with some useful descriptions.
        # The API documentation currently specifies errorCodes will be either
        # undef (null) or an array (list).
        if ( ref( $error_codes ) eq 'ARRAY' ) {

            $result->{errors}->{ $_ } = $self->translate_error_code( 'card-detail-status', $_ )
                foreach @$error_codes;

        }

    }

    catch {
        my $error = $_;
        $self->logger->warn( __PACKAGE__ . "::get_card_details_status - ERROR: $error" );
    };

    return $result;

}

=head2 init_with_payment_session

Initialise a card payment with the full card details. The response here will
be an init reference that can be used to make a pre-authorisation on the card
defined in this request. Parameter is a hashref of the form:

    { 'channel' => 'NAP-XT-INTL',
      'distributionCentre'  => 'NAP-DC1',
      'paymentMethod'       => 'CREDITCARD',
      'currency'            => 'GBP',
      'coinAmount'          => 100000,
      'billingCountry'      => 'GB',
      'isPreOrder'          => 'false',
      'title'               => 'Mr.',
      'firstName'           => 'Firsty',
      'lastName'            => 'Lastnom',
      'address1'            => '10 Address Line 1',
      'address2'            => 'Addressline2ville',
      'address3'            => undef,
      'postcode'            => 'W12 7GF',
      'merchantURL'         => 'http://www.net-a-porter.com',
      'email'               => 'firsty.lastnom@net-a-porter.com',
      'paymentSessionId'    => '80ed9f7645d439d4f231cc156c8a2e1b',
    }

The paymentSessionId is what's returned by C<create_new_payment_session>.

Note: The coinAmount field is always in the lowest denomination for the
particular currency.

=cut

sub init_with_payment_session {
    my ( $self, $data ) = @_;

    my $result = {};

    try {

        die __PACKAGE__ . '::init_with_payment_session - $data must be a HASH reference'
            unless ref( $data ) eq 'HASH';

        $result = $self->http_client->init_with_payment_session( $data );

    }

    catch {
        my $error = $_;
        $self->logger->warn( __PACKAGE__ . "::init_with_payment_session - ERROR: $error" );
    };

    return $result;

}

=head2 preauth_with_payment_session

Create a new payment pre-authorisation for a specific card and amount of
money. The amount is reserved on the card for a short period of time (the
period being dependent of the specific PSP) after which the reservation
lapses. The pre-auth reference can be used to settle the pre-auth which
actually transfers the money from the card. Pre-auths can be settled even if
the pre-auth reservation of funds period has lapsed as long as the card has
sufficient funds available at the time of settlement. Parameter is a hashref
of the form:

    { orderNumber => 236432      # NAP order number
      reference => 'ref-str' # The returned init_with_payment_session reference string,
      paymentSessionId => '80ed9f7645d439d4f231cc156c8a2e1b',
    }

The paymentSessionId is what's returned by C<create_new_payment_session>.

=cut

sub preauth_with_payment_session {
    my ( $self, $data ) = @_;

    my $result = {};

    try {

        die __PACKAGE__ . '::preauth_with_payment_session - $data must be a HASH reference'
            unless ref( $data ) eq 'HASH';

        $result = $self->http_client->preauth_with_payment_session( $data );

    }

    catch {
        my $error = $_;
        $self->logger->warn( __PACKAGE__ . "::preauth_with_payment_session - ERROR: $error" );
    };

    return $result;

}

=head2 payment_form

Returns a new instance of an L<XT::Domain::Payment::Form>, any arguments
given are used to instantiate the object..

=cut

sub payment_form {
    my ( $self, %arguments ) = @_;

    return XT::Domain::Payment::Form->new(
        domain_payment => $self,
        %arguments,
    );

}

=head2 get_refund_information( $settle_reference )

Get a list of refund information for a given C<$settle_reference>.

For details on the structure that is returned, please see:

http://confluence.net-a-porter.com/display/infosec/Payment+Utility+API+Calls

At present this is the following:

[
    {
        success         => 1,
        reason          => 'ACCEPTED',
        amountRefunded  => 30000,
        dateRefunded    => '2014-07-22T16 => 24 => 47.000+0000',
    }
]

=cut

sub get_refund_information {
    my ( $self, $settle_reference ) = @_;

    my $result = [];

    try {

        die __PACKAGE__ . '::get_refund_information - $settle_reference must be provided'
            unless defined $settle_reference;

        my $response = $self->http_client->get_refund_information( {
            settleReference => $settle_reference,
        } );

        die 'response is not an array' unless
            ref( $response ) eq 'ARRAY';

        $result = $response;

    }

    catch {
        my $error = $_;
        $self->logger->warn( __PACKAGE__ . "::get_refund_information - ERROR: $error" );
    };

    return $result;

}

sub payment_amendment {
    my $self = shift;
    my $data = shift;

    my $result;

    try {
        die __PACKAGE__ . '::payment_amendment - $data must be a HASH reference'
            unless ref( $data ) eq 'HASH';

        $result = $self->http_client->payment_amendment( $data);
    }
    catch {
        $self->logger->warn( $_ );
        $result  = {
            returnCodeResult => 9999,
            returnCodeReason => 'XTracker Error',
            extraReason      => 'Failed to make payment-amendement call to PSP '.$_,
            reference        => $data->{reference},
        }
    };

    return $result;
}


sub payment_replacement {
    my $self = shift;
    my $data = shift;

    my $result;

    try{
        die __PACKAGE__.'::payment_replacement - $data must be HASH Reference'
            unless ref( $data ) eq 'HASH';

        $result = $self->http_client->payment_replacement ( $data );
    }
    catch {
        $self->logger->warn( $_ );
        $result  = {
            returnCodeResult => 9999,
            returnCodeReason => 'XTracker Error',
            extraReason      => 'Failed to make payment-replacement call to PSP '.$_,
            reference        => $data->{reference},
        }
    };

    return $result;
}

sub _update_boolean_values {
    my ( $self, $data, @keys_to_update ) = @_;

    foreach my $key ( @keys_to_update ) {

        # Make sure the strings 'true' and 'false' are used, defaulting to
        # 'false', as this is what the service expects.
        $data->{ $key } = $data->{ $key } // 0
            ? 'true'
            : 'false';

    }

    return;

}

# TODO: Remove this method once the New Service is Live and in use
# helper to parse the response from the Client 'getinfo_payment' call
# and if needed to convert the old response into the new response
# specs for the new & old Services are here:
#   Old - http://confluence.net-a-porter.com/display/infosec/Deprecated+but+still+in+use+API+calls
#   New - http://confluence.net-a-porter.com/display/infosec/Payment+Utility+API+Calls
sub _parse_getinfo_payment_response {
    my ( $self, $payload ) = @_;

    # if there is a 'cardInfo' or 'paymentHistory' key in the payload
    # then it must be using the new format and can just return as is
    # (I'm using 1 of 2 keys for paranoia reasons 1 should be enough)
    return $payload     if ( exists( $payload->{cardInfo} ) || exists( $payload->{paymentHistory} ) );

    my $new_payload = dclone( $payload );

    # these fields should be placed in a 'cardInfo' section
    # and the 'cardInfo' section in the 'paymentHistory' section
    my @card_info_fields = qw(
        cardNumberFirstDigit
        cardNumberLastFourDigits
        cardExpiryMonth
        cardExpiryYear
        cardType
        cardIssuer
        cardCategory
        countryIssuer
        newCard
        storedCard
        cardAttempts
    );

    # set-up some effective constants
    my $default_payment_method  = 'CREDITCARD';
    my $default_payment_status  = 'ACCEPTED';


    # convert these keys
    $new_payload->{orderDate}        = delete $new_payload->{date};
    $new_payload->{preauthReference} = delete $new_payload->{preauthInternalReference};

    # add these keys
    $new_payload->{paymentMethod}           = $default_payment_method;
    $new_payload->{current_payment_status}  = $default_payment_status;
    $new_payload->{original_payment_status} = $default_payment_status;

    # get rid of these keys
    delete $new_payload->{message};


    # put the Card Details in a 'cardInfo' section
    my $card_info;
    foreach my $key ( @card_info_fields ) {
        $card_info->{ $key } = delete $new_payload->{ $key }
                                if ( exists $new_payload->{ $key } );
    }
    # add this in to 'cardInfo' if it exists
    $card_info->{storedCard} = delete $new_payload->{savedCard}
                if ( exists $new_payload->{savedCard} && !defined $card_info->{storedCard} );
    $new_payload->{cardInfo} = $card_info;


    # 'cardHistory' should become 'paymentHistory'
    my $payment_history = delete $new_payload->{cardHistory};
    if ( $payment_history ) {
        foreach my $payment ( @{ $payment_history } ) {
            # get the Card Details into a 'cardInfo' section
            my $card_info_hist;
            foreach my $key ( @card_info_fields ) {
                $card_info_hist->{ $key } = delete $payment->{ $key };
            }
            $payment->{cardInfo} = $card_info_hist;

            # convert these keys
            $payment->{orderDate} = delete $payment->{date};

            # add these keys
            $payment->{paymentMethod}           = $default_payment_method;
            $payment->{current_payment_status}  = $default_payment_status;
            $payment->{original_payment_status} = $default_payment_status;
        }
    }
    $new_payload->{paymentHistory} = $payment_history;

    return $new_payload;
}

sub translate_error_code {
    my ( $self, $call, $code ) = @_;

    $call //= '';
    $code //= '';

    my $unknown_error = "Unknown Error (no message for code '$code' of call '$call')" ;

    return $unknown_error
        unless $call && $code;

    my $codes = {
        'card-detail-status' => {
            51001 => q{Invalid paymentSessionId},
            51002 => q{No Saved Cards Found For Customer},
            54002 => q{Invalid characters in Card Number},
            54003 => q{No Card Type},
            54004 => q{Invalid Expiry Month},
            54005 => q{Invalid Expiry Year},
            54006 => q{No Card Number},
            54007 => q{Card Number too long or too short},
            54008 => q{Invalid Card Number i.e failed luhn check},
            54009 => q{Card Holder Name contains invalid characters},
            54010 => q{Expiry Date in the past},
            54011 => q{No CV2 (Security) number},
            54012 => q{Invalid Card Type},
            54013 => q{No Expiry Month},
            54014 => q{No Expiry Year},
            54015 => q{No Card Holder's Name},
            54016 => q{Card Holder's Name exceeds allowed length},
            54017 => q{Customer Card Token exceeds allowed length},
            54018 => q{Customer Card Token contains invalid characters},
            54019 => q{Too few or too many digits for security number},
            54020 => q{No Issue Number for Maestro card},
            54021 => q{No value for Site},
            54022 => q{Invalid value for Site},
            54023 => q{Value for site too long},
            54024 => q{No Admin Id},
            54025 => q{Invalid value for Admin Id},
            54026 => q{No customer Id},
            54027 => q{Invalid value for customer Id},
            54028 => q{No customer Card token when keepCard is set to true},
            55000 => q{General error with card data},
        },
    };

    return $codes->{ $call }->{ $code }
        // $unknown_error;

}

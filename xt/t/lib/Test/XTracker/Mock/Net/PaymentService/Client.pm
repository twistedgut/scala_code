package Test::XTracker::Mock::Net::PaymentService::Client;
use NAP::policy 'tt', 'test';

=head1 NAME

Test::XTracker::Mock::Net::PaymentService::Client

=head1 DESCRIPTION

This mocks features of 'XT::Net::PaymentService::Client'. Currently
mocks the following methods:

    * getinfo_payment

=cut

use Test::MockModule;
use XTracker::Config::Local qw/config_var/;

=head1 METHODS

=head2 mock

    $mocked_object = Test::XTracker::Mock::Net::PaymentService::Client->mock;

Will mock 'XT::Net::PaymentService::Client' and return a Mocked version of it.

=cut

sub mock {
    my $self = shift;

    my @methods_to_mock = qw(
        getinfo_payment
    );

    my $mocked = Test::MockModule->new( 'XT::Net::PaymentService::Client' );
    foreach my $method ( @methods_to_mock ) {
        my $mock_method = "mock_${method}";
        $mocked->mock( $method => sub { shift; return $self->$mock_method( @_ ); } );
    }

    return $mocked;
}

=head2 set_getinfo_payment_response

    __PACKAGE__->set_getinfo_payment_response( { payload } );
        or
    __PACKAGE__->set_getinfo_payment_response( undef );         # to use the default payment info

Use to set what the mocked 'getinfo_payment' method should return.

=cut

my $_getinfo_payment_response;
sub set_getinfo_payment_response {
    my ( $self, $payload ) = @_;

    $_getinfo_payment_response = $payload;

    return;
}

=head2 set_getinfo_payment__payment_method

    __PACKAGE__->set_getinfo_payment__payment_method( 'PAYPAL' );
        or
    __PACKAGE__->set_getinfo_payment__payment_method( 'default' );  # to set the default of 'CREDITCARD'
        or
    my $force_undef = 1;
    __PACKAGE__->set_getinfo_payment__payment_method( undef, $force_undef );   # to set to 'undef'

Sets the 'paymentMethod' that will be returned by the default
'getinfo_payment' response.

=cut

my $_payment_method = 'CREDITCARD';
sub set_getinfo_payment__payment_method {
    my ( $self, $method, $force ) = @_;

    $_payment_method = (
        $force || ( $method && lc( $method ) ne 'default' )
        ? $method
        : 'CREDITCARD'
    );

    return;
}

=head2 set_getinfo_payment__third_party_status

    __PACKAGE__->set_getinfo_payment__third_party_status( 'PENDING' );

set the Third Party PSP Current Status. Use this for testing
Third Party payment methods such as PayPal.

=cut

my $_third_party_psp_status;
sub set_getinfo_payment__third_party_status {
    my ( $self, $status ) = @_;

    $_third_party_psp_status = $status;

    return;
}

=head2 set_getinfo_payment__coin_amount

    # to set the coin amount for '1001.00'
    __PACKAGE__->set_getinfo_payment__coin_amount( 100100);

Sets the 'coinAmount' that will be returned by the default
'getinfo_payment' response.

Remember to 'coinAmount' is in PENCE.

=cut

my $_coin_amount;
sub set_getinfo_payment__coin_amount {
    my ( $self, $amount ) = @_;

    $_coin_amount = $amount;

    return $_coin_amount;
}

=head2 set_getinfo_payment__avs_response

    __PACKAGE__->set_getinfo_payment__avs_response( 'NO MATCH' );

Sets the 'cv2avsStatus' that will be returned by the default
'getinfo_payment' response.

Default is 'ALL MATCH'.

You can use the following to restore it to the default:

    __PACKAGE__->set_getinfo_payment__avs_response__default;

=cut

my $_cv2avs_status__default = 'ALL MATCH';
my $_cv2avs_status = $_cv2avs_status__default;
sub set_getinfo_payment__avs_response {
    my ( $self, $response ) = @_;

    $_cv2avs_status = $response;

    return;
}
sub set_getinfo_payment__avs_response__default {
    my ( $self ) = @_;

    $_cv2avs_status = $_cv2avs_status__default;

    return;
}

=head2 set_getinfo_payment__currency

    __PACKAGE__->set_getinfo_payment__currenct('EUR');

Sets the currency to 'EUR' that will be returned by
'getinfo_payment' response.

Default is ''.

=cut

my $_currency = config_var( 'Currency', 'local_currency_code' ) // '';
sub set_getinfo_payment__currency {
    my ( $self, $currency ) = @_;

    $_currency = $currency;

    return $_currency;
}

=head2 set_getinfo_payment__payment_history

    __PACKAGE__->set_getinfo_payment__payment_history(
        [
            {
                # payment_details
                ...
            },
            {
                # payment_details
                ...
            },
        ],
    );

Sets the 'paymentHistory' that will be returned by the default
'getinfo_payment' response.

Default is an empty Array.

You can use the following to restore it to the default:

    __PACKAGE__->set_getinfo_payment__payment_history__default;


=cut

my $_payment_history__default = [];
my $_payment_history = $_payment_history__default;
sub set_getinfo_payment__payment_history {
    my ($self,  $history ) = @_;

    $_payment_history = $history
        if ( ref( $history ) eq 'ARRAY' );

    return $_payment_history;
}
sub set_getinfo_payment__payment_history__default {
    my $self = shift;

    $_payment_history = $_payment_history__default;

    return $_payment_history;

}

=head2 set_getinfo_payment__settlements

    __PACKAGE__->set_getinfo_payment__settlements(
        [
            {
                # settlements_details
                ...
            },
            {
                # settlements_details
                ...
            },
        ],
    );

Sets the 'settlements' that will be returned by the default
'getinfo_payment' response.

Default is an empty Array.

You can use the following to restore it to the default:

    __PACKAGE__->set_getinfo_payment__settlements__default;


=cut

my $_settlements__default = [];
my $_settlements = $_settlements__default;
sub set_getinfo_payment__settlements {
    my ($self,  $settlements) = @_;

    $_settlements = $settlements
        if ( ref( $settlements ) eq 'ARRAY' );

    return $_settlements;
}
sub set_getinfo_payment__settlements__default {
    my $self = shift;

    $_settlements = $_settlements__default;

    return $_settlements;
}

# returns the default getinfo_payment response
# using the above 'set_getinfo_payment__*' methods
# to change some of the values
sub _default_getinfo_payment_response {
    my ( $self, $args ) = @_;

    return {
        paymentMethod               => $_payment_method,
        current_payment_status      => (
            ( defined $_payment_method && $_payment_method ne 'CREDITCARD' )
            ? $_third_party_psp_status
            : undef
        ),
        providerReference           => ( $args->{reference} || 'CARROT' ),
        coinAmount                  => $_coin_amount || 123456,
        cardInfo    => {
            cardType                    => 'DisasterCard',
            cardNumberFirstDigit        => 6,
            cardNumberLastFourDigits    => '6667',
        },
        cv2avsStatus                => $_cv2avs_status,
        paymentHistory              => $_payment_history,
        currency                    => $_currency,
        settlements                 => $_settlements,
    };
}

=head2 mock_getinfo_payment

Mocked version of 'XT::Net::PaymentService::Client->getinfo_payment'.

=cut

sub mock_getinfo_payment {
    my ( $self, $args ) = @_;

    return $_getinfo_payment_response //
            __PACKAGE__->_default_getinfo_payment_response( $args );
}


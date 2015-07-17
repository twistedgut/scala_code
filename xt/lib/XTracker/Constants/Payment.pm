package XTracker::Constants::Payment;

use strict;
use warnings;
use base 'Exporter';

use Readonly;

# CANDO-696
Readonly our $PAYMENT_CARD_TYPES_ARRAY => do { Readonly my @a => ('Visa', 'Electron', 'Amex', 'Mastercard', 'Delta', 'Maestro', 'JCB'); \@a };

our @PAYMENT_CARD_TYPES = qw(
    $PAYMENT_CARD_TYPES_ARRAY
);

Readonly our $PSP_RETURN_CODE__SUCCESS                 => 1;
Readonly our $PSP_RETURN_CODE__BANK_REJECT             => 2;
Readonly our $PSP_RETURN_CODE__MISSING_INFO            => 3;
Readonly our $PSP_RETURN_CODE__INTERNAL_SERVER_ERROR   => 4;
Readonly our $PSP_RETURN_CODE__3D_SECURE_BYPASSED      => 7;
Readonly our $PSP_RETURN_CODE__3D_SECURE_NOT_SUPPORTED => 8;
Readonly our $PSP_RETURN_CODE__CANCELLED_VOIDED        => 10;
Readonly our $PSP_RETURN_CODE__UNKNOWN_ERROR           => -1;
Readonly our $PSP_RETURN_CODE__DIFFERENT_CURRENCY      => -4;



our @PSP_RETURN_CODES = qw(
    $PSP_RETURN_CODE__SUCCESS
    $PSP_RETURN_CODE__BANK_REJECT
    $PSP_RETURN_CODE__MISSING_INFO
    $PSP_RETURN_CODE__3D_SECURE_BYPASSED
    $PSP_RETURN_CODE__3D_SECURE_NOT_SUPPORTED
    $PSP_RETURN_CODE__CANCELLED_VOIDED
    $PSP_RETURN_CODE__UNKNOWN_ERROR
    $PSP_RETURN_CODE__DIFFERENT_CURRENCY
    $PSP_RETURN_CODE__INTERNAL_SERVER_ERROR
);


Readonly our $PSP_CHANNEL_MAPPING_HASH => do { Readonly my %h => (
    'NET-A-PORTER.COM' => 'PaymentService_NAP',
    'theOutnet.com'    => 'PaymentService_OUTNET',
    'MRPORTER.COM'     => 'PaymentService_MRP',
); \%h };

our @PSP_CHANNEL_MAPPING = qw(
    $PSP_CHANNEL_MAPPING_HASH
);

my $settle_prefix_msg = '<strong>Settlement Failed:</strong> ';
my $settle_suffix_msg = "<br><br>Please try again but <strong>DO NOT</strong> use a different card. If this continues to fail then please seek help to settle this manually.";

Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__UNKNOWN_ERROR            => 'Sorry, an unknown error occured';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__UNKNOWN_RESPONSE         => 'Sorry, an unknown response was returned from the PSP';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__UNKNOWN_RESPONSE_AT_SETTLE => $settle_prefix_msg."Unknown response '%s' returned with message '%s'. ".$settle_suffix_msg;
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__ORDER_NOT_FOUND          => 'Order not found';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__NO_CARD_DETAILS          => 'No card details were provided';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__INVALID_CARD_DETAILS     => 'Invalid card details were provided';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__BANK_REJECT              => 'Bank rejected payment';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__BANK_REJECT_AT_SETTLE    => $settle_prefix_msg."Bank rejected payment with message '%s'. ".$settle_suffix_msg;
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__MISSING_PAYMENT_DETAILS  => 'Missing payment details';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__MISSING_DETAILS          => 'Missing details';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__MISSING_DETAILS_AT_SETTLE => $settle_prefix_msg."Missing details with message '%s'. ".$settle_suffix_msg;
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__TECHNICAL_ERROR          => 'Technical error';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_INIT           => 'Unable to Init payment';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_PREAUTH        => 'Unable to PreAuth payment';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_SETTLE         => $settle_prefix_msg.'Unable to settle payment. '.$settle_suffix_msg;
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_UPDATE_ORDER   => $settle_prefix_msg.'Unable to update order';
Readonly our $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_CONFIRM_ORDER  => 'Unable to confirm order';

our @PRE_ORDER_PAYMENT_API_MESSAGES = qw(
    $PRE_ORDER_PAYMENT_API_MESSAGE__UNKNOWN_ERROR
    $PRE_ORDER_PAYMENT_API_MESSAGE__UNKNOWN_RESPONSE
    $PRE_ORDER_PAYMENT_API_MESSAGE__UNKNOWN_RESPONSE_AT_SETTLE
    $PRE_ORDER_PAYMENT_API_MESSAGE__ORDER_NOT_FOUND
    $PRE_ORDER_PAYMENT_API_MESSAGE__NO_CARD_DETAILS
    $PRE_ORDER_PAYMENT_API_MESSAGE__INVALID_CARD_DETAILS
    $PRE_ORDER_PAYMENT_API_MESSAGE__BANK_REJECT
    $PRE_ORDER_PAYMENT_API_MESSAGE__BANK_REJECT_AT_SETTLE
    $PRE_ORDER_PAYMENT_API_MESSAGE__MISSING_PAYMENT_DETAILS
    $PRE_ORDER_PAYMENT_API_MESSAGE__MISSING_DETAILS
    $PRE_ORDER_PAYMENT_API_MESSAGE__MISSING_DETAILS_AT_SETTLE
    $PRE_ORDER_PAYMENT_API_MESSAGE__TECHNICAL_ERROR
    $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_INIT
    $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_PREAUTH
    $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_SETTLE
    $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_UPDATE_ORDER
    $PRE_ORDER_PAYMENT_API_MESSAGE__UNABLE_TO_CONFIRM_ORDER
);


our @EXPORT_OK = (
    @PAYMENT_CARD_TYPES,
    @PSP_CHANNEL_MAPPING,
    @PSP_RETURN_CODES,
    @PRE_ORDER_PAYMENT_API_MESSAGES,
);

our %EXPORT_TAGS = (
    'payment_card_types'             => [@PAYMENT_CARD_TYPES],
    'psp_channel_mapping'            => [@PSP_CHANNEL_MAPPING],
    'psp_return_codes'               => [@PSP_RETURN_CODES],
    'pre_order_payment_api_messages' => [@PRE_ORDER_PAYMENT_API_MESSAGES],
);

1;

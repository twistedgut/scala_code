package XTracker::Constants;

use strict;
use warnings;
use base 'Exporter';

use Readonly;

use XTracker::Constants::FromDB qw/
    :carrier
    :business
/;

# results per page
Readonly our $PER_PAGE    => 20;

# the id from the operator table for 'Application'
Readonly our $APPLICATION_OPERATOR_ID => 1;

# Chisel explains what we used this for:
# 16:17 <@chisel> it's one/our way of checking that a PID isn't going to make
#                 Pg error is we try to insert it in the normal int field
# 16:18 <@chisel> usually it's used to catch people that can't put commas in
#                 pid lists
# 16:19 <@chisel> not everywhere ... just places where we've seen people use
#                 >2147483647 as a PID
Readonly our $PG_MAX_INT => 2147483647;
Readonly our $PG_MIN_INT => -2147483648;
Readonly our @PG_TIME_UNITS => (qw/
    microseconds
    milliseconds
    second
    minute
    hour
    day
    week
    month
    quarter
    year
    decade
    century
    millennium
/);
# Used at the start of an error message to indicate a database
# client has been disconnected from the server
Readonly our $DB_DISCONNECTED_STRING => "DB_DISCONNECTED";

# Carrier Automation States
Readonly our $CARRIER_AUTOMATION_STATE_ON              => 'On';
Readonly our $CARRIER_AUTOMATION_STATE_OFF             => 'Off';
Readonly our $CARRIER_AUTOMATION_STATE_IMPORT_OFF_ONLY => 'Import_Off_Only';
Readonly our @CARRIER_AUTOMATION_STATES => (
    $CARRIER_AUTOMATION_STATE_ON,
    $CARRIER_AUTOMATION_STATE_OFF,
    $CARRIER_AUTOMATION_STATE_IMPORT_OFF_ONLY,
);

# Default values for sku_update messages
Readonly our $SKU_UPDATE_DEFAULT_NAME        => 'NO NAME';
Readonly our $SKU_UPDATE_DEFAULT_DESCRIPTION => 'NO DESCRIPTION';

Readonly our %CONVERT => (
    in => {
        cm => sub { $_[0] * 2.54 },
        in => sub { $_[0] * 1 },
    },
    cm => {
        in => sub { $_[0] / 2.54 },
        cm => sub { $_[0] * 1 },
    },
);

# The Dematic spec, which defines messages, acts as a good proxy for all PRL
# message specifications. However, it defines types poorly. Booleans are
# currently defined as strings of 'Y' and 'N', and we don't have enumerated
# family types, or channel types, etc.
# These are liable to change, and we're liable to find out at the last moment
# what they've actually used for these. To protect against this, we use PRL-
# specific types, meaning that if and when these change, we can respond to this
# quickly. It also protects against mistypes.
use NAP::DC::PRL::Tokens;
my @PRL_TYPE;
for my $type_name ( keys %NAP::DC::PRL::Tokens::dictionary ) {
    my $type = $NAP::DC::PRL::Tokens::dictionary{ $type_name };
    for my $option ( keys %$type ) {
        my $value = $type->{ $option };

        my $symbol = sprintf("PRL_TYPE__%s__%s",
            $type_name,
            $option
        );

        # Define the left-side as a read-only
        no strict 'refs';   ## no critic(ProhibitNoStrict)
        no warnings "once"; ## no critic(ProhibitNoWarnings)
        Readonly::Scalar ${$symbol} => $value;

        # Export it
        push( @PRL_TYPE, '$' . $symbol );
    }
}

# the Default Payment Method of 'Credit Card' which is
# used for backward compatibility with the PSP when
# getting Payment Info, as the Old Payment Info Service
# doesn't have a 'paymentMethod' field. This value will
# be used to against the 'payment_method' field on the
# 'orders.payment_method' record.
Readonly our $PSP_DEFAULT_PAYMENT_METHOD => 'Credit Card';

# error message shown when creating Refund Invoices as
# 'Card Refund' using the 'misc_refund' field (which is
# for pure Goodwill refunds) when the Payment Method for
# an Order can't handle Goodwill Refunds such as 'Klarna'
Readonly our $GOODWILL_REFUND_AGAINST_CARD_ERR_MSG =>
    # this string should be used with 'sprintf'
    'Payment provider (%s) cannot support good will refund to card. Good will refund to be issued as store credit.';


# set up export tags

Readonly our @PAGING => qw( $PER_PAGE );

Readonly our @APPLICATION => qw( $APPLICATION_OPERATOR_ID );

Readonly our @DATABASE => qw( $PG_MAX_INT $PG_MIN_INT @PG_TIME_UNITS $DB_DISCONNECTED_STRING );

Readonly our @CARRIER_AUTOMATION_STATE => qw(
    $CARRIER_AUTOMATION_STATE_ON
    $CARRIER_AUTOMATION_STATE_OFF
    $CARRIER_AUTOMATION_STATE_IMPORT_OFF_ONLY
    @CARRIER_AUTOMATION_STATES
);

# Purchase order import responses for messages
Readonly our $MESSAGE_RESPONSE_STATUS_ERROR      => 'ERROR';
Readonly our $MESSAGE_RESPONSE_STATUS_SUCCESS    => 'SUCCESS';

our @MESSAGE_RESPONSES = qw(
    $MESSAGE_RESPONSE_STATUS_ERROR
    $MESSAGE_RESPONSE_STATUS_SUCCESS
);

Readonly our $DEFAULT_TOTE_COMPARTMENT_CONFIGURATION => 'TOTE';
Readonly our @SKU_UPDATE_DEFAULTS => qw(
    $SKU_UPDATE_DEFAULT_NAME
    $SKU_UPDATE_DEFAULT_DESCRIPTION
);

# PRL

Readonly our $PRL_LOCATION_NAME__FULL    => 'Full';
Readonly our $PRL_LOCATION_NAME__DEMATIC => 'Dematic';
Readonly our @PRL_LOCATION_NAME => qw(
    $PRL_LOCATION_NAME__FULL
    $PRL_LOCATION_NAME__DEMATIC
);

# Shipping Option Service:

Readonly our $SOS_SHIPMENT_CLASS__STANDARD => 'STANDARD';
Readonly our $SOS_SHIPMENT_CLASS__PREMIER_DAYTIME => 'PREMIER_DAYTIME';
Readonly our $SOS_SHIPMENT_CLASS__PREMIER_EVENING => 'PREMIER_EVENING';
Readonly our $SOS_SHIPMENT_CLASS__PREMIER_ALL_DAY => 'PREMIER_ALL_DAY';
Readonly our $SOS_SHIPMENT_CLASS__STAFF => 'STAFF';
Readonly our $SOS_SHIPMENT_CLASS__TRANSFER => 'TRANSFER';
Readonly our $SOS_SHIPMENT_CLASS__EMAIL => 'EMAIL';
Readonly our $SOS_SHIPMENT_CLASS__NOMDAY => 'NOMDAY';
Readonly our $SOS_SHIPMENT_CLASS__PREMIER_HAMPTONS => 'PREMIER_HAMPTONS';
Readonly our @SOS_SHIPMENT_CLASS => qw(
    $SOS_SHIPMENT_CLASS__STANDARD
    $SOS_SHIPMENT_CLASS__STAFF
    $SOS_SHIPMENT_CLASS__TRANSFER
    $SOS_SHIPMENT_CLASS__EMAIL
    $SOS_SHIPMENT_CLASS__NOMDAY
    $SOS_SHIPMENT_CLASS__PREMIER_DAYTIME
    $SOS_SHIPMENT_CLASS__PREMIER_EVENING
    $SOS_SHIPMENT_CLASS__PREMIER_ALL_DAY
    $SOS_SHIPMENT_CLASS__PREMIER_HAMPTONS
);

Readonly our $SOS_CARRIER__DHL => 'DHL';
Readonly our $SOS_CARRIER__UPS => 'UPS';
Readonly our $SOS_CARRIER__NAP => 'NAP';
Readonly our @SOS_CARRIER => qw(
    $SOS_CARRIER__DHL
    $SOS_CARRIER__UPS
    $SOS_CARRIER__NAP
);

Readonly our $SOS_DELIVERY_EVENT_TYPE__ATTEMPTED => 'ATTEMPTED';
Readonly our $SOS_DELIVERY_EVENT_TYPE__COMPLETED => 'COMPLETED';
Readonly our @SOS_DELIVERY_EVENT_TYPE => qw(
    $SOS_DELIVERY_EVENT_TYPE__ATTEMPTED
    $SOS_DELIVERY_EVENT_TYPE__COMPLETED
);

Readonly our @PSP_DEFAULTS => qw(
    $PSP_DEFAULT_PAYMENT_METHOD
);

Readonly our @REFUND_ERROR_MESSAGES => qw(
    $GOODWILL_REFUND_AGAINST_CARD_ERR_MSG
);

Readonly our $SOS_CHANNEL__NAP => 'NAP';
Readonly our $SOS_CHANNEL__TON => 'TON';
Readonly our $SOS_CHANNEL__MRP => 'MRP';
Readonly our $SOS_CHANNEL__JC => 'JC';
Readonly our @SOS_CHANNEL => qw(
    $SOS_CHANNEL__NAP
    $SOS_CHANNEL__TON
    $SOS_CHANNEL__MRP
    $SOS_CHANNEL__JC
);

Readonly our $XT_CARRIER_TO_SOS_CARRIER_MAP => do { Readonly my %h   => (
    $CARRIER__UNKNOWN       => $SOS_CARRIER__NAP,
    $CARRIER__UPS           => $SOS_CARRIER__UPS,
    $CARRIER__DHL_EXPRESS   => $SOS_CARRIER__DHL,
    $CARRIER__DHL_GROUND    => $SOS_CARRIER__DHL,
); \%h };

Readonly our @CARRIER_SOS_MAP => qw( $XT_CARRIER_TO_SOS_CARRIER_MAP );

Readonly our $SOS_CARRIER_TO_XT_CARRIER_MAP => do { Readonly my %h   => (
    $SOS_CARRIER__NAP        => [ $CARRIER__UNKNOWN ],
    $SOS_CARRIER__UPS        => [ $CARRIER__UPS ],
    $SOS_CARRIER__DHL        => [ $CARRIER__DHL_EXPRESS, $CARRIER__DHL_GROUND ],
); \%h };

Readonly our @SOS_CARRIER_MAP => qw( $SOS_CARRIER_TO_XT_CARRIER_MAP );

Readonly our $XT_BUSINESS_TO_SOS_CARRIER_MAP => do { Readonly my %h   => (
    $BUSINESS__NAP   => $SOS_CHANNEL__NAP,
    $BUSINESS__OUTNET=> $SOS_CHANNEL__TON,
    $BUSINESS__MRP   => $SOS_CHANNEL__MRP,
    $BUSINESS__JC    => $SOS_CHANNEL__JC,
); \%h };

Readonly our @BUSINESS_MAP => qw( $XT_BUSINESS_TO_SOS_CARRIER_MAP );

Readonly our @CONVERSIONS => qw(
    %CONVERT
);

# export everything

our @EXPORT_OK = (
    '$DEFAULT_TOTE_COMPARTMENT_CONFIGURATION',
    @APPLICATION,
    @CARRIER_AUTOMATION_STATE,
    @CONVERSIONS,
    @DATABASE,
    @PAGING,
    @PRL_TYPE,
    @PRL_LOCATION_NAME,
    @SKU_UPDATE_DEFAULTS,
    @MESSAGE_RESPONSES,
    @SOS_SHIPMENT_CLASS,
    @SOS_CARRIER,
    @PSP_DEFAULTS,
    @REFUND_ERROR_MESSAGES,
    @SOS_CHANNEL,
    @CARRIER_SOS_MAP,
    @SOS_CARRIER_MAP,
    @BUSINESS_MAP,
    @SOS_DELIVERY_EVENT_TYPE
);

our %EXPORT_TAGS = (
    'all'                       => [@EXPORT_OK],
    'application'               => [qw($APPLICATION_OPERATOR_ID)],
    'carrier_automation'        => [@CARRIER_AUTOMATION_STATE],
    'conversions'               => [@CONVERSIONS],
    'database'                  => [@DATABASE],
    'prl_type'                  => [@PRL_TYPE],
    'prl_location_name'         => [@PRL_LOCATION_NAME],
    'sku_update'                => [@SKU_UPDATE_DEFAULTS],
    'message_response'          => [@MESSAGE_RESPONSES],
    'sos_shipment_class'        => [@SOS_SHIPMENT_CLASS],
    'sos_carrier'               => [@SOS_CARRIER],
    'psp_default'               => [@PSP_DEFAULTS],
    'refund_error_messages'     => [@REFUND_ERROR_MESSAGES],
    'sos_channel'               => [@SOS_CHANNEL],
    'carrier_sos_map'           => [@CARRIER_SOS_MAP],
    'sos_carrier_map'           => [@SOS_CARRIER_MAP],
    'business_map'              => [@BUSINESS_MAP],
    'sos_delivery_event_type'   => [@SOS_DELIVERY_EVENT_TYPE],
);

1;

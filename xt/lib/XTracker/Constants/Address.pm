package XTracker::Constants::Address;

use strict;
use warnings;
use base 'Exporter';

use Readonly;

# CANDO-696
Readonly our $ADDRESS_AJAX_MESSAGE__CANT_FIND_ADDRESS_ID          => 'Cant find address id';
Readonly our $ADDRESS_AJAX_MESSAGE__NO_ADDRESS_TYPE_PROVIDED      => 'No address type provided';
Readonly our $ADDRESS_AJAX_MESSAGE__UNKNOWN_ADDRESS_TYPE_PROVIDED => 'Unknown address type provided';
Readonly our $ADDRESS_AJAX_MESSAGE__CANT_CREATE_ADDRESS           => 'Cant create address';
Readonly our $ADDRESS_AJAX_MESSAGE__MISSING_PARAM                 => "Parameter '%s' is missing";
Readonly our $ADDRESS_AJAX_MESSAGE__CANT_UPDATE_ORDER_ADDRESS     => "Cant update order address";

our @ADDRESS_AJAX_MESSAGES = qw(
    $ADDRESS_AJAX_MESSAGE__CANT_FIND_ADDRESS_ID
    $ADDRESS_AJAX_MESSAGE__NO_ADDRESS_TYPE_PROVIDED
    $ADDRESS_AJAX_MESSAGE__UNKNOWN_ADDRESS_TYPE_PROVIDED
    $ADDRESS_AJAX_MESSAGE__CANT_CREATE_ADDRESS
    $ADDRESS_AJAX_MESSAGE__MISSING_PARAM
    $ADDRESS_AJAX_MESSAGE__CANT_UPDATE_ORDER_ADDRESS
);

# CANDO-696
Readonly our $ADDRESS_TYPE__SHIPMENT => 'Shipment';
Readonly our $ADDRESS_TYPE__INVOICE  => 'Invoice';

our @ADDRESS_TYPES = qw(
    $ADDRESS_TYPE__SHIPMENT
    $ADDRESS_TYPE__INVOICE
);

Readonly our $ADDRESS_UPDATE_MESSAGE__BILLING_AND_SHIPPING_ADDRESS_SAME
    => "The Billing Address will also be updated to be the same as the Shipping Address because of this Order's Payment Method";

our @ADDRESS_UPDATE_MESSAGES = qw(
    $ADDRESS_UPDATE_MESSAGE__BILLING_AND_SHIPPING_ADDRESS_SAME
);

our @EXPORT_OK = (
    @ADDRESS_AJAX_MESSAGES,
    @ADDRESS_TYPES,
    @ADDRESS_UPDATE_MESSAGES,
);

our %EXPORT_TAGS = (
    'address_ajax_messages'       => [@ADDRESS_AJAX_MESSAGES],
    'address_types'               => [@ADDRESS_TYPES],
    'address_update_messages'     => [@ADDRESS_UPDATE_MESSAGES],
);

1;

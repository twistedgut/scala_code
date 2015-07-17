package XTracker::Constants::Reservations;

use strict;
use warnings;
use base 'Exporter';

use Readonly;

# CANDO-696
Readonly our $RESERVATION_TYPE__RESERVATION => 'Reservation';
Readonly our $RESERVATION_TYPE__PRE_ORDER   => 'Pre Order';

our @RESERVATION_TYPES = qw(
    $RESERVATION_TYPE__RESERVATION
    $RESERVATION_TYPE__PRE_ORDER
);

# CANDO-696
Readonly our $RESERVATION_ADDRESS_TYPE__SHIPMENT => 'Shipment';
Readonly our $RESERVATION_ADDRESS_TYPE__INVOICE  => 'Invoice';

our @RESERVATION_ADDRESS_TYPES = qw(
    $RESERVATION_ADDRESS_TYPE__SHIPMENT
    $RESERVATION_ADDRESS_TYPE__INVOICE
);

# CANDO-696

# please keep these lines sorted by variable name, so that the chance
# of accidentally creating the same name twice is reduced
Readonly our $RESERVATION_MESSAGE__ADDRESS_UPDATED              => 'Address updated';
Readonly our $RESERVATION_MESSAGE__CANT_CREATE_NEW_ADDRESS      => 'Unable to create new address. Using previous address';
Readonly our $RESERVATION_MESSAGE__CANT_CREATE_PRE_ORDER        => 'Unable to create pre-order record';
Readonly our $RESERVATION_MESSAGE__CANT_CREATE_PRE_ORDER_ITEM   => 'Unable to create pre-order item record';
Readonly our $RESERVATION_MESSAGE__CANT_FETCH_STORE_CREDIT      => 'Unable to fetch store credit';
Readonly our $RESERVATION_MESSAGE__CANT_FIND_PRODUCT            => 'Product %d does not exist in the database';
Readonly our $RESERVATION_MESSAGE__CANT_FIND_PRODUCT_DATA       => 'Sorry, unable to fetch data for product %d';
Readonly our $RESERVATION_MESSAGE__CANT_FIND_VARIANT            => 'Sorry, unable to fetch data for variant %d';
Readonly our $RESERVATION_MESSAGE__CANT_FIND_VARIANT_IN_DB      => 'Could not find variant %d in the database';
Readonly our $RESERVATION_MESSAGE__CANT_GET_TAX_INFO            => 'Unable to get up-to-date tax information';
Readonly our $RESERVATION_MESSAGE__CANT_UPDATE_PRE_ORDER        => 'Unable to update pre-order record';
Readonly our $RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND           => 'Customer not found';
Readonly our $RESERVATION_MESSAGE__CUSTOMER_NOT_ON_PWS          => 'Customer does not exist on web site';
Readonly our $RESERVATION_MESSAGE__INVALID_CUSTOMER_ID          => 'Invalid customer ID';
Readonly our $RESERVATION_MESSAGE__INVALID_PREORDER_NUMBER      => 'Invalid pre-order number';
Readonly our $RESERVATION_MESSAGE__INVALID_PRODUCT_ID           => '%d is an invalid product ID';
Readonly our $RESERVATION_MESSAGE__NOTHING_TO_RESERVE           => 'Nothing to reserve';
Readonly our $RESERVATION_MESSAGE__NOT_A_PID_OR_SKU             => q{'%d' is not a valid PID or SKU};
Readonly our $RESERVATION_MESSAGE__NOT_A_VALID_VERTEX_ADDRESS   => 'Address not recognized for tax purposes';
Readonly our $RESERVATION_MESSAGE__NO_PRE_ORDER_WITHOUT_PAYMENT => 'Unable to process pre-order with payment';
Readonly our $RESERVATION_MESSAGE__NO_PRODUCTS_SELECTED         => 'No products selected';
Readonly our $RESERVATION_MESSAGE__NO_RSV_SRC_SELECTED          => 'No reservation source selected';
Readonly our $RESERVATION_MESSAGE__NO_RSV_TYPE_SELECTED         => 'No reservation type selected';
Readonly our $RESERVATION_MESSAGE__NO_STOCK_TO_RESERVE          => 'No stock to reserve for %s';
Readonly our $RESERVATION_MESSAGE__PRE_ORDER_FAIL               => '%s was has not been ordered';
Readonly our $RESERVATION_MESSAGE__PRE_ORDER_NOT_FOUND          => 'Pre-order not found';
Readonly our $RESERVATION_MESSAGE__PRE_ORDER_SUCCESS_FOR_ALL    => 'All items have been pre-ordered';
Readonly our $RESERVATION_MESSAGE__PRE_ORDER_SUCCESS_FOR_ITEM   => '%s has been pre-ordered';
Readonly our $RESERVATION_MESSAGE__PRODUCT_WRONG_CHANNEL        => 'Product %d does not exist in this channel';
Readonly our $RESERVATION_MESSAGE__RESERVATION_FAIL             => '%s was has not been reserved';
Readonly our $RESERVATION_MESSAGE__RESERVATION_SUCCESS          => '%s has been reserved';
Readonly our $RESERVATION_MESSAGE__UNABLE_TO_CONNECT_TO_PWS     => 'Unable to connect to PWS database. Please try again.';
Readonly our $RESERVATION_MESSAGE__UNABLE_TO_UPDATE_TAX_INFO    => 'Unable to update pre-order with up-to-date tax information';
Readonly our $RESERVATION_MESSAGE__UNABLE_TO_PRE_ORDER_SKUS     => 'No Longer able to Pre-Order these SKU(s): %s';
Readonly our $RESERVATION_MESSAGE__UNKNOWN_ADDRESS_TYPE         => 'Unkown address type';
Readonly our $RESERVATION_MESSAGE__ALREADY_GOT_PAYMENT_RECORD   => "This Pre-Order has already begun the Payment process and has a Pre-Auth assigned to it and can't be edited any longer.<br><br>Please Complete Payment or go to the Pre-Order Summary page to Cancel.<br><br>Pre-Order Number: %s";

# please keep these sorted too, so that you can see by comparing the
# shape of this block and the one above whether or not any of the
# above declarations are missing
our @RESERVATION_MESSAGES = qw(
    $RESERVATION_MESSAGE__ADDRESS_UPDATED
    $RESERVATION_MESSAGE__CANT_CREATE_NEW_ADDRESS
    $RESERVATION_MESSAGE__CANT_CREATE_PRE_ORDER
    $RESERVATION_MESSAGE__CANT_CREATE_PRE_ORDER_ITEM
    $RESERVATION_MESSAGE__CANT_FETCH_STORE_CREDIT
    $RESERVATION_MESSAGE__CANT_FIND_PRODUCT
    $RESERVATION_MESSAGE__CANT_FIND_PRODUCT_DATA
    $RESERVATION_MESSAGE__CANT_FIND_VARIANT
    $RESERVATION_MESSAGE__CANT_FIND_VARIANT_IN_DB
    $RESERVATION_MESSAGE__CANT_GET_TAX_INFO
    $RESERVATION_MESSAGE__CANT_UPDATE_PRE_ORDER
    $RESERVATION_MESSAGE__CUSTOMER_NOT_FOUND
    $RESERVATION_MESSAGE__CUSTOMER_NOT_ON_PWS
    $RESERVATION_MESSAGE__INVALID_CUSTOMER_ID
    $RESERVATION_MESSAGE__INVALID_PREORDER_NUMBER
    $RESERVATION_MESSAGE__INVALID_PRODUCT_ID
    $RESERVATION_MESSAGE__NOTHING_TO_RESERVE
    $RESERVATION_MESSAGE__NOT_A_PID_OR_SKU
    $RESERVATION_MESSAGE__NOT_A_VALID_VERTEX_ADDRESS
    $RESERVATION_MESSAGE__NO_PRE_ORDER_WITHOUT_PAYMENT
    $RESERVATION_MESSAGE__NO_PRODUCTS_SELECTED
    $RESERVATION_MESSAGE__NO_RSV_SRC_SELECTED
    $RESERVATION_MESSAGE__NO_RSV_TYPE_SELECTED
    $RESERVATION_MESSAGE__NO_STOCK_TO_RESERVE
    $RESERVATION_MESSAGE__PRE_ORDER_FAIL
    $RESERVATION_MESSAGE__PRE_ORDER_NOT_FOUND
    $RESERVATION_MESSAGE__PRE_ORDER_SUCCESS_FOR_ALL
    $RESERVATION_MESSAGE__PRE_ORDER_SUCCESS_FOR_ITEM
    $RESERVATION_MESSAGE__PRODUCT_WRONG_CHANNEL
    $RESERVATION_MESSAGE__RESERVATION_FAIL
    $RESERVATION_MESSAGE__RESERVATION_SUCCESS
    $RESERVATION_MESSAGE__UNABLE_TO_CONNECT_TO_PWS
    $RESERVATION_MESSAGE__UNABLE_TO_UPDATE_TAX_INFO
    $RESERVATION_MESSAGE__UNABLE_TO_PRE_ORDER_SKUS
    $RESERVATION_MESSAGE__UNKNOWN_ADDRESS_TYPE
    $RESERVATION_MESSAGE__ALREADY_GOT_PAYMENT_RECORD
);

Readonly our $RESERVATION_PRE_ORDER__DEFAULT_PACKAGING_TYPE => 'SIGNATURE';

our @RESERVATION_PRE_ORDER__PACKAGING_TYPES_EXPORT = qw(
    $RESERVATION_PRE_ORDER__DEFAULT_PACKAGING_TYPE
);

# CANDO-1019
Readonly our $RESERVATION_PRE_ORDER_IMPORTER__EMAIL_TEMPLATE                => 'email/internal/preorder_order_import_and_hold.tt';
Readonly our $RESERVATION_PRE_ORDER_IMPORTER__EMAIL_SUBJECT                 => 'Urgent-Process Pre-Order %s for %s';
Readonly our $RESERVATION_PRE_ORDER_IMPORTER__EMAIL_ADDRESS_CONFIG_SETTING  => 'personalshopping_email';

our @RESERVATION_PRE_ORDER_IMPORTER = qw(
    $RESERVATION_PRE_ORDER_IMPORTER__EMAIL_TEMPLATE
    $RESERVATION_PRE_ORDER_IMPORTER__EMAIL_SUBJECT
    $RESERVATION_PRE_ORDER_IMPORTER__EMAIL_ADDRESS_CONFIG_SETTING
);

our @EXPORT_OK = (
    @RESERVATION_MESSAGES,
    @RESERVATION_PRE_ORDER__PACKAGING_TYPES_EXPORT,
    @RESERVATION_TYPES,
    @RESERVATION_PRE_ORDER_IMPORTER,
    @RESERVATION_ADDRESS_TYPES
);

our %EXPORT_TAGS = (
    'reservation_messages'           => [@RESERVATION_MESSAGES],
    'reservation_address_types'      => [@RESERVATION_ADDRESS_TYPES],
    'reservation_types'              => [@RESERVATION_TYPES],
    'reservation_pre_order_importer' => [@RESERVATION_PRE_ORDER_IMPORTER],
    'pre_order_packaging_types'      => [@RESERVATION_PRE_ORDER__PACKAGING_TYPES_EXPORT]
);

1;

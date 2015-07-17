package XTracker::Constants::PreOrderRefund;

use strict;
use warnings;
use base 'Exporter';

use Readonly;


#refund class
Readonly our $PRE_ORDER_REFUND_CLASS__REFUND => 9999;

# refund type
Readonly our $PRE_ORDER_REFUND_TYPE__REFUND  => 9999;

Readonly our $PRE_ORDER_REFUND_TYPE__REFUND_NAME => 'Card Refund';
Readonly our $PRE_ORDER_REFUND_CLASS__REFUND_NAME => 'Cancel';

our @PRE_ORDER_REFUND_CLASS = qw (
    $PRE_ORDER_REFUND_CLASS__REFUND
    $PRE_ORDER_REFUND_CLASS__REFUND_NAME
);

our @PRE_ORDER_REFUND_TYPE = qw (
    $PRE_ORDER_REFUND_TYPE__REFUND
    $PRE_ORDER_REFUND_TYPE__REFUND_NAME
);

our @EXPORT_OK = (
    @PRE_ORDER_REFUND_CLASS,
    @PRE_ORDER_REFUND_TYPE,
);

our %EXPORT_TAGS = (
    'pre_order_refund_class' => [ @PRE_ORDER_REFUND_CLASS],
    'pre_order_refund_type'  => [ @PRE_ORDER_REFUND_TYPE],
);

1;

package XTracker::Constants::PreOrder;

use strict;
use warnings;
use base 'Exporter';

use Readonly;

use XTracker::Constants::FromDB         qw( :department );

# CANDO-1107
Readonly our $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SECTION     => 'Stock Control';
Readonly our $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SUBSECTION  => 'Reservation';
Readonly our $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_DEPARTMENTS => [ $DEPARTMENT__PERSONAL_SHOPPING,
                                                                             $DEPARTMENT__FASHION_ADVISOR ];

our @PRE_ORDER_OPERATOR_CONTROL = qw(
    $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SECTION
    $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_SUBSECTION
    $PRE_ORDER_OPERATOR_CONTROL__OPERATOR_TRANSFER_DEPARTMENTS
);

# CANDO-1107
Readonly our $PRE_ORDER_MESSAGE__OPERATOR_TRANSFER_SUCCESS => 'Pre order was successfully transferred to %s';
Readonly our $PRE_ORDER_MESSAGE__OPERATOR_TRANSFER_FAILURE => 'Unable to transfer pre order to %s';

our @PRE_ORDER_MESSAGES = qw(
    $PRE_ORDER_MESSAGE__OPERATOR_TRANSFER_SUCCESS
    $PRE_ORDER_MESSAGE__OPERATOR_TRANSFER_FAILURE
);

our @EXPORT_OK = (
    @PRE_ORDER_OPERATOR_CONTROL,
    @PRE_ORDER_MESSAGES
);

our %EXPORT_TAGS = (
    'pre_order_operator_control' => [@PRE_ORDER_OPERATOR_CONTROL],
    'pre_order_messages'         => [@PRE_ORDER_MESSAGES]
);

1;

package XTracker::Order::Finance::ActiveInvoices;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::Handler;
use XTracker::Database::Invoice;
use XTracker::Constants::FromDB qw( :renumeration_class :renumeration_type );
use XTracker::Constants::PreOrderRefund qw( :pre_order_refund_class :pre_order_refund_type );



### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    $handler->{data}{content}       = 'ordertracker/finance/activerefunds.tt';
    $handler->{data}{section}       = 'Finance';
    $handler->{data}{subsection}    = 'Active Invoices';
    unless ( $handler->{data}{datalite} ) {
        $handler->{data}{invoices}      = get_active_invoices($handler->{schema});
    }
    $handler->{data}{error_msg}     = $handler->{request}->param('error_msg');

    # arrays of renumerations classes and types
    # to loop over and display on page
    $handler->{data}{classes}   = [
        { id => $RENUMERATION_CLASS__ORDER,         title => 'Order Amendments' },
        { id => $RENUMERATION_CLASS__GRATUITY,      title => 'Gratuity' },
        { id => $RENUMERATION_CLASS__CANCELLATION,  title => 'Cancellation' },
        { id => $RENUMERATION_CLASS__RETURN,        title => 'Returns' },
        { id => $PRE_ORDER_REFUND_CLASS__REFUND,    title => 'PreOrder'}
    ];
    $handler->{data}{types}     = [
        { id => $RENUMERATION_TYPE__CARD_REFUND,    title => 'Card Refunds' },
        { id => $RENUMERATION_TYPE__STORE_CREDIT,   title => 'Store Credits' },
        { id => $RENUMERATION_TYPE__CARD_DEBIT,     title => 'Debits' },
        { id => $PRE_ORDER_REFUND_TYPE__REFUND,     title => 'Card Refunds' }
    ];

    $handler->{data}{pre_order_type_id} = $PRE_ORDER_REFUND_TYPE__REFUND;

    # load css & javascript for tab view
    $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css','/css/shared/refund_history.css'];
    $handler->{data}{js}    = ['/javascript/xui.js','/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js','/javascript/api/payment.js','/javascript/popup/refund_history_active_invoices.js'];

    $handler->process_template( undef );

    return OK;
}


1;


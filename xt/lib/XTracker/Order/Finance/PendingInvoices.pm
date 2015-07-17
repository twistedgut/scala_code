package XTracker::Order::Finance::PendingInvoices;

use strict;
use warnings;

use XTracker::Handler;

use XTracker::Database::Invoice qw( get_pending_invoices );
use XTracker::Constants::FromDB qw( :renumeration_class :renumeration_type );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    $handler->{data}{content}       = 'ordertracker/finance/pendingrefunds.tt';
    $handler->{data}{section}       = 'Finance';
    $handler->{data}{subsection}    = 'Pending Invoices';
    $handler->{data}{invoices}      = get_pending_invoices($handler->{dbh});

    # arrays of renumerations classes and types
    # to loop over and display on page
    $handler->{data}{classes}   = [
        { id => $RENUMERATION_CLASS__ORDER,         title => 'Order Amendments' },
        { id => $RENUMERATION_CLASS__GRATUITY,      title => 'Gratuity' },
        { id => $RENUMERATION_CLASS__CANCELLATION,  title => 'Cancellation' },
        { id => $RENUMERATION_CLASS__RETURN,        title => 'Returns' }
    ];
    $handler->{data}{types}     = [
        { id => $RENUMERATION_TYPE__CARD_REFUND,    title => 'Card Refunds' },
        { id => $RENUMERATION_TYPE__STORE_CREDIT,   title => 'Store Credits' },
        { id => $RENUMERATION_TYPE__CARD_DEBIT,     title => 'Debits' }
    ];

    # load css & javascript for tab view
    $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    return $handler->process_template( undef );
}

1;

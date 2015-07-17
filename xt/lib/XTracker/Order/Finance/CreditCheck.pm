package XTracker::Order::Finance::CreditCheck;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Finance     qw( get_credit_check_orders );
use XTracker::Database::Currency    qw( get_currency_glyph_map );


### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    $handler->{data}{content}       = 'ordertracker/finance/creditcheck.tt';
    $handler->{data}{section}       = 'Finance';
    $handler->{data}{subsection}    = 'Credit Check';
    $handler->{data}{currency_glyph}= get_currency_glyph_map( $handler->{dbh} );
    $handler->{data}{orders}        = get_credit_check_orders($handler->{schema});
    $handler->{data}{sidenav}       = [ {
        "None" => [ {
            'title' => 'Key to Icons',
            'url'   => '/Finance/CreditCheck/Icons',
            'popup' => 'key_to_finance_icons',
        } ],
    } ];

    # load css & javascript for tab view
    $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}    = [
        '/yui/yahoo-dom-event/yahoo-dom-event.js',
        '/yui/element/element-min.js',
        '/yui/tabview/tabview-min.js',
        '/javascript/jquery.tablesorter.min.js',
        '/javascript/popup/xt_popup_args.js',
    ];

    return $handler->process_template( undef );
}

1;

package XTracker::Order::CustomerCare::ReturnsPending;

use strict;
use warnings;
use XTracker::Handler;
use XTracker::Database::Return qw(:DEFAULT get_returns_pending );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get view type from url - defaults to 'severely' late returns
    $handler->{data}{view_type}     = $handler->{param_of}{view_type} || 'Severely_Late';

    $handler->{data}{section}       = 'Customer Care';
    $handler->{data}{subsection}    = 'Returns Pending';
    $handler->{data}{subsubsection} = $handler->{data}{view_type};
    $handler->{data}{subsubsection} =~ s/_/ /g;
    $handler->{data}{content}       = 'ordertracker/customercare/returnspending.tt';


    $handler->{data}{sidenav}       = [ { 'View' =>
                                        [
                                            {   title => 'All',
                                                url   => "/CustomerCare/ReturnsPending?view_type=All",
                                            },
                                            {   title => 'Late',
                                                url   => "/CustomerCare/ReturnsPending?view_type=Late",
                                            },
                                            {   title => 'Severely Late',
                                                url   => "/CustomerCare/ReturnsPending?view_type=Severely_Late",
                                            },
                                            {   title => 'Partial',
                                                url   => "/CustomerCare/ReturnsPending?view_type=Partial",
                                            },
                                            {   title => 'Defective',
                                                url   => "/CustomerCare/ReturnsPending?view_type=Defective",
                                            },
                                            {   title => 'Awaiting Authorisation',
                                                url   => "/CustomerCare/ReturnsPending?view_type=Awaiting_Authorisation",
                                            },
                                            {   title => 'Premier',
                                                url   => "/CustomerCare/ReturnsPending?view_type=Premier",
                                            },
                                        ],
                                    }
    ];


    # get return lists
    $handler->{data}{returns}   = get_returns_pending( $handler->{dbh}, $handler->{data}{view_type} );

    # load css & javascript for tab view
    $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    return $handler->process_template( undef );
}

1;

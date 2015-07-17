package XTracker::Order::Finance::Icons;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Finance qw( get_finance_icons );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    $handler->{data}{subsubsection} = 'Key to Icons';
    $handler->{data}{template_type} = 'blank';
    $handler->{data}{content}       = 'ordertracker/finance/icons.tt';

    $handler->{data}{icons} = get_finance_icons( $handler->{dbh} );

    $handler->process_template( undef );

    return OK;

}


1;

__END__

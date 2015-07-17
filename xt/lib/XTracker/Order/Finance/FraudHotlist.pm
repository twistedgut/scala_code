package XTracker::Order::Finance::FraudHotlist;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Finance qw( get_hotlist_values get_hotlist_fields );
use XTracker::Database::Channel qw( get_channels );


### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    $handler->{data}{content}       = 'ordertracker/finance/fraudhotlist.tt';
    $handler->{data}{section}       = 'Finance';
    $handler->{data}{subsection}    = 'Fraud Hotlist';
    $handler->{data}{hotlist}       = get_hotlist_values($handler->{dbh});
    $handler->{data}{fields}        = get_hotlist_fields($handler->{dbh});
    $handler->{data}{channels}      = get_channels($handler->{dbh});

    # pre-process hotlist with field type as the hash key
    foreach my $record ( keys %{$handler->{data}{hotlist}} ) {
        $handler->{data}{list}{ $handler->{data}{hotlist}{$record}{field} }{ $record } = $handler->{data}{hotlist}{$record};
    }

    return $handler->process_template( undef );
}

1;

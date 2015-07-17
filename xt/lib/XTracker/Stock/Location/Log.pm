package XTracker::Stock::Location::Log;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Try::Tiny;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dump qw(pp);
use Time::ParseDate;
use XTracker::Handler;
use XTracker::Error qw( xt_warn );
use XTracker::Session;
use XTracker::Navigation qw( get_navtype build_nav build_sidenav );
use XTracker::Database;
use XTracker::Database::Location qw( get_location_log );

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new( $r );

    my $session  = XTracker::Session->session();
    my $location = $handler->{param_of}{location_id};

    $handler->{data}{content}           = 'stocktracker/location/log.tt';
    $handler->{data}{section}           = 'Stock Control';
    $handler->{data}{subsection}        = 'Location';
    $handler->{data}{subsubsection}     = 'Log';

    $handler->{data}{sidenav}           = build_sidenav({navtype => get_navtype({
        type            => 'location',
        auth_level      => $session->{auth_level}
    })});

    $handler->{data}{location}          = $location;

    return try {
        $handler->{data}{location_log}      = get_location_log( $handler->dbh, $location );

        foreach my $date ( keys %{$handler->{data}{location_log}} ) {
            my $dt = DateTime->from_epoch( epoch => scalar parsedate($date) );
            $handler->{data}{location_log}->{$date}->{parsed_date}
                = $dt->day_abbr  ." " .
                  $dt->mday      ." " .
                  $dt->month_abbr." ".
                  $dt->year      .", ".
                  $dt->hour      .":" .
                  sprintf("%02d",$dt->minute);
        }

        $handler->process_template( undef );

        return OK;
    }
    catch {
        xt_warn($_);

        return $handler->redirect_to( '/StockControl/Location/SearchLocationsForm' );
    };
}

1;

__END__



package XTracker::Stock::Check::Location;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Navigation;
use XTracker::Database::Location qw( get_stock_in_location );
use XTracker::Error qw( xt_warn );
use XTracker::Utilities qw( :string );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $location = trim( $handler->{param_of}{location} );

    $handler->{data}{scan}          = { action      => '/StockControl/StockCheck/Location',
                                        field       => 'location',
                                        name        => 'Location'
                                      };

    # TT data structure
    if ( $handler->{data}{handheld} ) {
        $handler->{data}{content}   = 'check/handheld/location.tt';
        $handler->{data}{sidenav}   = {};
        $handler->{data}{view}      = 'HandHeld';
    }
    else {
        $handler->{data}{section}           = 'Stock Check';
        $handler->{data}{subsection}        = 'Check Location';
        $handler->{data}{content}           = 'check/location.tt';
        $handler->{data}{sidenav}           = build_sidenav( { navtype => 'stock_check' } );
    }

    eval {
        if( $location ){
            $handler->{data}{variants} = get_stock_in_location( $handler->dbh, $location );
        }
    };

    if ($@) {
        xt_warn($@);
    }

    $handler->process_template( undef );

    return OK;
}

1;

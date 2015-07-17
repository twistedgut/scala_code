package XTracker::Stock::Check::Summary;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::XTemplate;
use XTracker::Navigation;
use XTracker::Database;
use XTracker::Database::Stock;
use XTracker::Database::Product;

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r   = shift;
    my $req = $r; # they're the same thing in our new Plack world
    my $dbh = read_handle();

    # TT data structure
    my $data = {
        mainnav => build_nav(1),
        sidenav => build_sidenav( { navtype => 'stock_check' } ),
    };

    # Create the template and process to produce the html
    #my $html = "";
    my $template = XTracker::XTemplate->template();
    $r->content_type('text/html');
    $template->process( 'check/summary.tt', $data, $r );

    # cache the output for next time
    #$cache->set( $cachekey, $html, "10 minutes" );

    # output the page
    #$r->content_type('text/html');
    #$r->print($html);


    return OK;
}


1;

__END__

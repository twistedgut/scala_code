package XTracker::Stock::Inventory::FinalPick;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    eval {
        # TT data structure
        $handler->{data}{content}   = 'inventory/final_pick.tt';
        $handler->{data}{locations} = $handler->{schema}->resultset('Public::Quantity')->get_empty_locations;
        $handler->{data}{sidenav}   = {};
        $handler->{data}{section}   = "Final Pick";
        $handler->{data}{css}       = ['/yui/tabview/assets/skins/sam/tabview.css'];
        $handler->{data}{js}        = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];
    };

    if ($@) {
        $handler->{data}{error} = $@;
    }

    $handler->process_template( undef );

    return OK;
}

1;

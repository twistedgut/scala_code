package XTracker::Stock::DeadStock::List;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Stock qw( get_dead_stock_list );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new( $r );

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Dead Stock';
    $handler->{data}{content}       = 'deadstock/list.tt';

    # get list of units in dead stock
    $handler->{data}{list}          = get_dead_stock_list( $handler->{dbh} );

    # link to add dead stock quantities
    push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Add Item to Dead Stock', 'url' => '/StockControl/DeadStock/AddItem' } );

    # load css & javascript for tab view
    $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    $handler->process_template( undef );

    return OK;
}

1;

__END__

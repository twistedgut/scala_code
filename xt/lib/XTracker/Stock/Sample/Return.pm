package XTracker::Stock::Sample::Return;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Navigation                qw( build_sidenav );
use XTracker::Database::StockTransfer   qw( get_stock_transfer_returns );

sub handler {
    my $handler = XTracker::Handler->new(shift);


    $handler->{data}{content}           = 'stocktracker/sample/return.tt';
    $handler->{data}{section}           = 'Stock Control';
    $handler->{data}{subsection}        = 'Sample';
    $handler->{data}{subsubsection}     = 'Transfer Returns';
    $handler->{data}{sidenav}           = build_sidenav( { navtype => 'stockc_sample' } );

    $handler->{data}{rmas}              = get_stock_transfer_returns( $handler->{dbh}, {type => 'all', id => undef } );

    $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
    $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];

    $handler->process_template( undef );

    return OK;
}

1;

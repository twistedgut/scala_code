package XTracker::Stock::DeadStock::AddItem;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Channel qw( get_channels );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Dead Stock';
    $handler->{data}{subsubsection} = 'Add Item';
    $handler->{data}{content}       = 'deadstock/add_item.tt';
    $handler->{data}{channels}      = get_channels( $handler->{dbh} );

    # back link for left nav
    push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => '/StockControl/DeadStock' } );

    $handler->process_template( undef );

    return OK;

}

1;

__END__

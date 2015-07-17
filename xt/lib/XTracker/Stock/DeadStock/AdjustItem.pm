package XTracker::Stock::DeadStock::AdjustItem;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database::Product qw( get_product_data get_product_summary );
use XTracker::Database::Stock qw( get_dead_stock );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new( $r );

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Dead Stock';
    $handler->{data}{subsubsection} = 'Process Item';
    $handler->{data}{content}       = 'deadstock/process_item.tt';

    # get quantity id from url
    $handler->{data}{quantity_id}   = $handler->{param_of}{quantity_id};

    # kick user back to list if not defined
    if ( not defined $handler->{data}{quantity_id} ){
        return $handler->redirect_to( '/StockControl/DeadStock' );
    }

    # back link for left nav
    push( @{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => '/StockControl/DeadStock' } );

    # get quantity info
    $handler->{data}{info} = get_dead_stock( $handler->{dbh}, $handler->{data}{quantity_id} );

    # product info for display
    my $product = get_product_data( $handler->{dbh}, { type => "product_id", id => $handler->{data}{info}{product_id} } );
    $handler->{data}{product_id} = $product->{id};
    $handler->add_to_data( get_product_summary( $handler->{schema}, $product->{id} ) );

    $handler->process_template( undef );

    return OK;

}

1;

__END__

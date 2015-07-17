package XTracker::Stock::PurchaseOrder::Edit;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Navigation;

use XTracker::Database::Attributes qw( :DEFAULT );
use XTracker::Database::Product;
use XTracker::Database::Stock qw( get_delivered_quantity );
use XTracker::Database::PurchaseOrder qw( get_purchase_order );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section} = 'Stock Control';
    $handler->{data}{subsection}    = 'Purchase Order';
    $handler->{data}{subsubsection} = 'Edit';
    $handler->{data}{content}       = 'purchase_order/edit.tt';

    # po id from url
    $handler->{data}{po_id}         = $handler->{param_of}{po_id} || 0;

    # Check if this specific PO is editable here, otherwise bail out
    my $purchase_order = $handler->schema->resultset('Public::PurchaseOrder')->find( $handler->{data}{po_id} );
    return if( $purchase_order && !$purchase_order->is_editable_in_xt );

    # build side nav links
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'purchase_order_summary', po_id => $handler->{data}{po_id} } );

    # get po details
    if ( $handler->{data}{po_id} ) {

        $handler->{data}{purchase_order_id} = $handler->{data}{po_id};
        $handler->{data}{purchase_order}    = get_purchase_order( $handler->{dbh}, $handler->{data}{po_id}, 'purchase_order_id' )->[0];
        $handler->{data}{sales_channel}     = $handler->{data}{purchase_order}{sales_channel};
        $handler->{data}{seasons}           = [ 'season',   get_season_atts( $handler->{dbh} ) ];
        $handler->{data}{acts}              = [ 'act', get_season_act_atts( $handler->{dbh} ) ];
    }

    $handler->process_template( undef );

    return OK;
}

1;

__END__

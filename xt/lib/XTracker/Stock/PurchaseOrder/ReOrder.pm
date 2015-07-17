package XTracker::Stock::PurchaseOrder::ReOrder;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Navigation;
use XTracker::Image qw( get_image_list );
use XTracker::Database qw( get_schema_using_dbh );
use XTracker::Database::Attributes;
use XTracker::Database::PurchaseOrder qw( get_purchase_order get_stock_orders get_stock_order_items );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Purchase Order';
    $handler->{data}{subsubsection} = 'Re-Order';
    $handler->{data}{content}       = 'purchase_order/reorder.tt';

    # po id from url
    $handler->{data}{po_id}         = $handler->{param_of}{po_id} || 0;

    # Check if this specific PO is editable here, otherwise bail out
    my $purchase_order = $handler->schema->resultset('Public::PurchaseOrder')->find( $handler->{data}{po_id} );
    return if( $purchase_order && !$purchase_order->is_editable_in_xt );

    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'purchase_order_summary', po_id => $handler->{data}{po_id} } );

    # get po details
    if ( $handler->{data}{po_id} ) {

        $handler->{data}{purchase_order_id} = $handler->{data}{po_id};
        $handler->{data}{purchase_order}    = get_purchase_order( $handler->{dbh}, $handler->{data}{po_id}, 'purchase_order_id' )->[0];
        $handler->{data}{sales_channel}     = $handler->{data}{purchase_order}{sales_channel};
        $handler->{data}{stock_orders}      = get_stock_orders( $handler->{dbh}, { purchase_order_id => $handler->{data}{po_id} } );
        $handler->{data}{images}            = get_image_list(
            get_schema_using_dbh($handler->{dbh},'xtracker_schema'),
            $handler->{data}{stock_orders} );

        # get stock order items
        foreach my $so_ref ( @{ $handler->{data}{stock_orders} } ) {
                $handler->{data}{stock_order_items}{ $so_ref->{id} } = get_stock_order_items( $handler->{dbh}, { type => 'stock_order_id', id => $so_ref->{id} } );
        }

    }

    # load css & javascript for calendar
    $handler->{data}{css}   = ['/yui/calendar/assets/skins/sam/calendar.css'];
    $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/calendar/calendar-min.js', '/javascript/NapCalendar.js'];

    $handler->process_template( undef );

    return OK;
}


1;

__END__

package XTracker::Stock::PurchaseOrder::Confirm;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Database qw( get_schema_using_dbh );
use XTracker::Database::Attributes;
use XTracker::Database::Pricing       qw( get_pricing );
use XTracker::Database::Profile       qw( get_operator );
use XTracker::Database::PurchaseOrder qw( get_purchase_order get_stock_orders get_stock_order_items_advanced get_product get_payment_terms
                                          is_purchase_order_confirmed );
use XTracker::Image qw( get_image_list );
use XTracker::Navigation;

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Purchase Order';
    $handler->{data}{subsubsection} = 'Confirm';
    $handler->{data}{content}       = 'purchase_order/confirm.tt';

    # po id from url
    $handler->{data}{po_id}         = $handler->{param_of}{po_id} || 0;

    # build side nav links
    $handler->{data}{sidenav}       = build_sidenav( { navtype => 'purchase_order_summary', po_id => $handler->{data}{po_id} } );

    # get po details
    if ( $handler->{data}{po_id} ) {

        # Check if this specific PO is editable here, otherwise bail out
        my $purchase_order = $handler->schema->resultset('Public::PurchaseOrder')->find( $handler->{data}{po_id} );
        return if( $purchase_order && !$purchase_order->is_editable_in_xt );

        $handler->{data}{enable_edit_purchase_order} = 1; # It is editable in XT

        $handler->{data}{purchase_order_id} = $handler->{data}{po_id};
        $handler->{data}{purchase_order}    = get_purchase_order( $handler->{dbh}, $handler->{data}{po_id}, 'purchase_order_id' )->[0];
        $handler->{data}{sales_channel}     = $handler->{data}{purchase_order}{sales_channel};
        $handler->{data}{stock_order_items} = get_stock_order_items_advanced( { dbh => $handler->{dbh}, type => 'purchase_order_id', id => $handler->{data}{po_id} } );
        $handler->{data}{stock_orders}      = get_stock_orders( $handler->{dbh}, { purchase_order_id => $handler->{data}{po_id} } );
        $handler->{data}{images}            = get_image_list(
            get_schema_using_dbh($handler->{dbh},'xtracker_schema'),
            $handler->{data}{stock_orders} );
        $handler->{data}{payment_terms}     = get_payment_terms( $handler->{dbh}, { type => 'purchase_order_id', id => $handler->{data}{po_id} } );

        $handler->{data}{purchase_order_confirmed} = is_purchase_order_confirmed( { dbh => $handler->{dbh}, purchase_order_id => $handler->{data}{po_id} } );
        ( $handler->{data}{confirmed_name}, $handler->{data}{confirmed_username} ) = get_operator( { dbh => $handler->{dbh}, id => $handler->{data}{purchase_order_confirmed} } );

    }

    $handler->process_template( undef );

    return OK;
}


1;

__END__

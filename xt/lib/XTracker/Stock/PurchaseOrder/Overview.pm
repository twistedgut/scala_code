package XTracker::Stock::PurchaseOrder::Overview;
use strict;
use warnings;
use Carp;
use XTracker::Handler;
use XTracker::Image qw( get_image_list );
use XTracker::Navigation qw( build_sidenav );
use XTracker::Database qw( get_schema_using_dbh );
use XTracker::Database::Attributes;
use XTracker::Database::Stock qw( get_delivered_quantity get_ordered_quantity );
use XTracker::Database::PurchaseOrder qw( is_confirmed get_purchase_order get_stock_orders );

sub handler {
    my $h     = XTracker::Handler->new(shift);

    $h->{data}{section}       = 'Stock Control';
    $h->{data}{subsection}    = 'Purchase Order';
    $h->{data}{subsubsection} = 'Overview';
    $h->{data}{content}       = 'purchase_order/overview.tt';

    # po id from url
    $h->{data}{po_id}         = $h->{param_of}{po_id} || 0;

    my $purchase_order = $h->schema->resultset('Public::PurchaseOrder')->find( $h->{data}{po_id} );
    $h->{data}{enable_edit_purchase_order} = $purchase_order && $purchase_order->is_editable_in_xt  ;

    $h->{data}{sidenav} = build_sidenav(
    {
        navtype => 'purchase_order_summary'.( $h->{data}{enable_edit_purchase_order} ? "" : "_no_edit" ),
        po_id => $h->{data}{po_id}
    }
    );


    # If legacy features are not to be used, then we need to remove all the items
    # from the Purchase Order section of the sidebar except for Overview
    unless($h->{data}{enable_edit_purchase_order}){
        $h->{data}{sidenav}->[1]->{"Purchase Order"} = [grep {$_->{title} eq "Overview"} @{$h->{data}{sidenav}->[1]->{"Purchase Order"}}];
    }

    # get po details
    if ( $h->{data}{po_id} ) {
        $h->{data}{purchase_order_id} = $h->{data}{po_id};
        $h->{data}{purchase_order}    = get_purchase_order( $h->{dbh}, $h->{data}{po_id}, 'purchase_order_id' )->[0];
        $h->{data}{sales_channel}     = $h->{data}{purchase_order}{sales_channel};
        $h->{data}{stock_orders}      = get_stock_orders( $h->{dbh}, { purchase_order_id => $h->{data}{po_id} } );
        $h->{data}{images}            = get_image_list(
            get_schema_using_dbh($h->{dbh},'xtracker_schema'),
            $h->{data}{stock_orders} );
        $h->{data}{ordered}           = get_ordered_quantity( $h->{dbh}, { type => 'purchase_order_id', id => $h->{data}{po_id} } );
        $h->{data}{delivered}         = get_delivered_quantity( $h->{dbh}, { type => 'purchase_order_id', id => $h->{data}{po_id} } );
        $h->{data}{seasons}           = [ 'season',   get_season_atts( $h->{dbh} ) ];
        $h->{data}{designers}         = [ 'designer', get_designer_atts( $h->{dbh} ) ];
        $h->{data}{purchase_order_cancelled} = $purchase_order->cancel;
    }

    return $h->process_template( undef );
}

1;

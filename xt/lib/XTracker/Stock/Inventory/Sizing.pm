package XTracker::Stock::Inventory::Sizing;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::Navigation qw( get_navtype build_sidenav );
use XTracker::Database::Attributes qw ( get_size_schemes
    get_size_atts_with_size_scheme );
use XTracker::Database::Profile qw( get_department );
use XTracker::Database::Stock;
use XTracker::Database::Product qw (:DEFAULT get_product_summary);

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Inventory';
    $handler->{data}{subsubsection} = 'Sizing';
    $handler->{data}{content}       = 'stocktracker/inventory/sizing.tt';
    $handler->{data}{javascript}    = 'product.tt';

    # get product from url
    $handler->{data}{product_id}    = $handler->{param_of}{product_id};

    # hash of arguments to pass to functions
    $handler->{data}{sidenav}   = build_sidenav( { type => 'product_id', id => $handler->{data}{product_id}, navtype => get_navtype( { dbh => $handler->{dbh}, auth_level => $handler->{data}{auth_level}, type => 'product', id => $handler->{data}{operator_id} } ) } );

    # get common product summary data for header
    $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{param_of}{product_id} ) );

    $handler->{data}{department}  = get_department( {id => $handler->{data}{operator_id} } );

    # Fetch list of variants
    my $variant_list_ref    = get_variant_list( $handler->{dbh}, {
        type => 'product_id',
        id => $handler->{data}{product_id},
        return => 'List',
        type_id => 1,
        add_designer_size_id => 1,
    } );

    # Fetch delivered quantities for each variant.
    my %delivered_qty   = ();
    foreach ( @$variant_list_ref ) {
        my $variant_id = $_->{id};
        my $delivered_qty_ref   = get_delivered_quantity( $handler->{dbh}, { type => 'variant_id', id => $variant_id, index => 'variant_id' } );
        $delivered_qty{$variant_id} = $delivered_qty_ref->{$variant_id}{quantity};
    }

    $handler->{data}{variants}        = $variant_list_ref;
    $handler->{data}{delivered_qty}   = \%delivered_qty;
    $handler->{data}{sizes} = get_size_atts_with_size_scheme( $handler->{dbh} );
    $handler->{data}{size_schemes}    = get_size_schemes( $handler->{dbh} );

    #Check if all the purchase orders which contain this product are editable;

    my $purchase_order_rs = $handler->schema->resultset('Public::PurchaseOrder')->search({ id => [keys %{$handler->{data}{purchase_orders}}] });
    while(my $po = $purchase_order_rs->next()){
        unless($po->is_editable_in_xt){
            # If one of the PO's is not editable in XT, then sizing for this PID becomes uneditable,
            # so we use the non editable sizing template instead
            $handler->{data}{content} = 'stocktracker/inventory/sizing_not_editable.tt';
            last;
        }
    }

    $handler->process_template( undef );

    return OK;
}


1;

__END__

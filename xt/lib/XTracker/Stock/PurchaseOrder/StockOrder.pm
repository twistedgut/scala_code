package XTracker::Stock::PurchaseOrder::StockOrder;

use strict;
use warnings;
use Carp;

use DateTime::Format::Pg;

use XTracker::Error;
use XTracker::Handler;
use XTracker::Navigation;
use XTracker::Database::Product qw( get_product_summary get_variant_list );
use XTracker::Database::Stock qw( get_delivered_quantity );
use XTracker::Database::PurchaseOrder qw( get_purchase_order_id get_stock_orders get_stock_order_items );

sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    eval {
        my $so_id       = $handler->{param_of}{'so_id'} || 0;

        $handler->{data}{section}                    = 'Stock Control';
        $handler->{data}{subsection}                 = 'Purchase Order';
        $handler->{data}{subsubsection}              = 'Stock Order';
        $handler->{data}{content}                    = 'purchase_order/stock_order.tt';

        $handler->{data}{sidenav} = build_sidenav({
            #navtype       => $handler->{data}{enable_edit_purchase_order} ? 'stock_order' : 'purchase_order_summary_no_edit',
            navtype       => 'purchase_order_summary_no_edit',
            operator_id   => $handler->operator_id,
            department_id => $handler->department_id,
            auth_level    => $handler->auth_level,
            so_id         => $so_id,
            po_id         => get_purchase_order_id( $dbh, {
                id   => $so_id,
                type => 'stock_order_id',
            }),
        });

        my $stock_order
            = $schema->resultset('Public::StockOrder')->find($so_id);

        $handler->{data}{product_id} = $stock_order->product->id;

        $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

        my $purchase_order = $stock_order->purchase_order;
        $handler->{data}{purchase_order} = $purchase_order;
        $handler->{data}{sales_channel} = $purchase_order->channel->name;
        $handler->{data}{enable_edit_purchase_order} = $purchase_order->is_editable_in_xt;

        # get stock order details
        $handler->{data}{stock_order} = get_stock_orders(
            $dbh, { stock_order_id => $so_id } )->[0];

        # DCS-2251 - This is a workaround in order not to change the
        # underlying method call (get_stock_orders) too much as it's used in
        # several places and don't want to break anything... - DJ

        foreach ( qw{parse_start_date parse_cancel_date} ) {
            $handler->{data}{stock_order}{$_}
                = $handler->{data}{stock_order}{$_}
                ? DateTime::Format::Pg->parse_timestamp( $handler->{data}{stock_order}{$_} )
                : '';
        }

        # Voucher-specific conditional starts here...
        my $variant_list = {};
        if ( $purchase_order->is_voucher_po ) {
            # In order to appease the template prepare the delivered and items
            # refs as if they were normal products
            for ( $stock_order->stock_order_items->all ) {
                $handler->{data}{delivered}{$_->id} = {
                    quantity            => $_->get_delivered_quantity,
                    stock_order_item_id => $_->id,
                };
                push @{ $handler->{data}{items} }, {
                    original_quantity => $_->original_quantity,
                    status            => $_->status->status,
                    designer_size     => 'N/A - Voucher',
                    quantity          => $_->quantity,
                    size              => 'N/A - Voucher',
                    variant_id        => $_->voucher_variant_id,
                    cancel            => $_->cancel,
                    type              => 'Stock', # FIXME: This shouldn't be hard-coded, even for vouchers... grab this from super_variant
                    id                => $_->id,
                    size_id           => $_->voucher_variant->size_id,
                    status_id         => $_->status_id,
                };
            }
        }
        else {
            # get a hash of all possible sizes for product
            $variant_list = get_variant_list($dbh,
                { type    => 'product_id',
                type_id => 1,
                id      => $handler->{data}{product_id}
                },
                { by => 'size_list' }
            );
            $handler->{data}{delivered} = get_delivered_quantity(
                $dbh,
                { type  => 'stock_order_id',
                  id    => $so_id,
                  index => 'stock_order_item_id'
                },
            );
            $handler->{data}{items} = get_stock_order_items(
                $dbh, { type => 'stock_order_id', id => $so_id } );
            my %sizeid_to_varid;
            # get hash of sizes by size_id
            foreach my $varkey ( keys %{$variant_list} ) {
                $sizeid_to_varid{$variant_list->{$varkey}{size_id}} = $varkey;
            }

            # delete out of variant_list hash all sizes in get_stock_order_items
            foreach my $item ( @{ $handler->{data}{items} } ) {
                if ( exists $sizeid_to_varid{$item->{size_id}} ) {
                    delete $variant_list->{$sizeid_to_varid{$item->{size_id}}};
                }
            }
            $handler->{data}{missing_sizes} = $variant_list;
        }
    };
    if( $@ ){
        xt_warn( $@ );
    }
    return $handler->process_template;
}

1;

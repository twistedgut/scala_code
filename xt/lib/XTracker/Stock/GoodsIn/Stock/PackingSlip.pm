package XTracker::Stock::GoodsIn::Stock::PackingSlip;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Product qw( get_product_summary );
use XTracker::Error;

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $data = {
        stock_order_id => $handler->{request}->param('so_id'),
        section        => 'Goods In',
        subsection     => 'Stock In',
        subsubsection  => 'Packing Slip',
        content        => 'goods_in/stock/packing_slip.tt',
        # form field data
        scan => {
            name   => 'Product Id',
            action => 'PackingSlip',
            field  => 'product_id',
        },
    };

    my $schema = $handler->{schema};
    my $stock_order = $schema->resultset('Public::StockOrder')->find(
        $data->{stock_order_id}
    );

    unless ( $stock_order ) {
        xt_warn( 'The Stock Order you selected could not be found' );
        return $handler->redirect_to(
            $handler->{referer} || '/GoodsIn/StockIn'
        );
    }

    $data->{stock_order} = $stock_order;
    $data->{stock_order_items} = [
        $stock_order->stock_order_items->search(undef,
            { prefetch => 'variant',
              order_by => 'variant.size_id',
            }
        )->all
    ];

    unless ( $stock_order->can_create_packing_slip  ) {
        xt_warn 'Cannot enter packing slip values: '
            . $stock_order->why_cannot_create_packing_slip;
        $data->{disable_packing_slip_form} = 1;
    }

    # Left nav links
    push @{ $data->{sidenav}[0]{'None'} },
        { 'title' => 'Back', 'url' => "/GoodsIn/StockIn" };

    # We need these for page_elements/display_product.tt to display properly
    my $purchase_order = $stock_order->purchase_order;
    $data->{sales_channel} = $purchase_order->channel->name;

    $data->{product_id} = $stock_order->product_id || $stock_order->voucher_product_id;
    @{$handler->{data}}{keys %{$data}} = values %{$data};
    $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );

    return $handler->process_template;
}

1;

package XTracker::Stock::GoodsIn::Stock::ItemCount;

use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Carp;
use Data::Dump qw(pp);

use XTracker::Handler;
use XTracker::Constants::FromDB qw( :department);
use XTracker::Database::Attributes qw( get_shipping_attributes );
use XTracker::Database::Product  qw( get_product_summary );
use XTracker::Error;
use XTracker::Config::Local qw( config_var );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    my $data = {
        section         => 'Goods In',
        subsection      => 'Item Count',
        subsubsection   => '',
        content         => 'goods_in/stock/item_count.tt',
        show_item_count => $handler->department_id == $DEPARTMENT__DISTRIBUTION_MANAGEMENT
                        || $handler->department_id == $DEPARTMENT__STOCK_CONTROL,
    };

    # Redirect to printer selection screen unless operator has one set
    return $handler->redirect_to($handler->printer_station_uri)
        unless $handler->operator->has_location_for_section('item_count');

    my $schema = $handler->{schema};
    my $item_count_list_uri = '/GoodsIn/ItemCount';
    # Delivery id defined then we're processing a product
    if ( my $delivery_field = $handler->{request}->param('delivery_id') ) {

        my ( $delivery_id ) = ( $delivery_field =~ m{^\s*(\d+)\s*$} );

        unless ( $delivery_id ) {
            xt_warn("Delivery $delivery_field is not a valid delivery id\n");
            return $handler->redirect_to($item_count_list_uri);
        }

        my $delivery = $schema->resultset('Public::Delivery')->find( $delivery_id );

        unless ( $delivery ) {
            xt_warn("Delivery $delivery_id not found\n");
            return $handler->redirect_to($item_count_list_uri);
        }

        if ( $delivery->is_cancelled ) {
            xt_warn("Delivery $delivery_id has been cancelled, please contact a supervisor.");
            return $handler->redirect_to($item_count_list_uri);
        }
        if ( $delivery->on_hold ) {
            xt_warn("Delivery $delivery_id is currently on hold, please contact a supervisor.");
            return $handler->redirect_to($item_count_list_uri);
        }

        $data->{delivery_id} = $delivery_id;
        $data->{subsubsection} = 'Process Item';

        # form field data
        $data->{scan} = {
            name   => 'Delivery Id',
            action => 'Book',
            field  => 'delivery_id',
        };

        # left nav links
        push @{ $data->{sidenav}[0]{'None'} },
            { 'title' => 'Back',
              'url'   => $item_count_list_uri };
        push @{ $data->{sidenav}[0]{'None'} },
            { 'title' => 'Hold Delivery',
              'url'   => "/GoodsIn/DeliveryHold/HoldDelivery?delivery_id=$delivery_id" };

        my $stock_order = $delivery->stock_order;
        $data->{delivered} = { map {
            $_->variant->id => $_->get_delivered_quantity
        } $stock_order->stock_order_items->all };

        my $purchase_order = $stock_order->purchase_order;

        # Sales channel for delivery
        $data->{sales_channel} = $purchase_order->channel->name;

        $data->{countries}
            = [ $schema->resultset('Public::Country')->by_name->all ];

        if ( $data->{is_product_po} = $purchase_order->is_product_po ) {
            $data->{delivery_items} = [
                $delivery->delivery_items
                         ->search_new_items
                         ->prefetch_variants
                         ->all
            ];

            $data->{product_id} = $stock_order->product_id;

            $data->{attributes} = get_shipping_attributes(
                $handler->{dbh}, $stock_order->product_id
            )->[0];

            @{$handler->{data}}{keys %{$data}} = values %{$data};

            # Get common product summary data for header
            $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );
        }
        else {
            # A Voucher PO
            $data->{delivery_items} = [
                $delivery->delivery_items
                         ->search_new_items
                         ->prefetch_stock_order_items
                         ->all
            ];

            my $voucher = $stock_order->product;
            $data->{product} = {
                id => $voucher->id,
                name => $voucher->name,
                designer => 'Gift Voucher',
            };
            $handler->{data}{product_id} = $voucher->id;


            $data->{purchase_orders} = {
                $purchase_order->id => {
                    purchase_order_number => $purchase_order->purchase_order_number,
                }
            };
            @{$handler->{data}}{keys %{$data}} = values %{$data};
            $handler->add_to_data( get_product_summary( $handler->{schema}, $handler->{data}{product_id} ) );
        }
    }
    # No delivery defined show list
    else {
        $data->{scan} = {
            action  => $item_count_list_uri,
            field   => 'delivery_id',
            name    => 'Delivery Id',
            title   => 'Item Count',
        };

        push @{ $data->{sidenav}[0]{None} }, {
            title => 'Set Item Count Station',
            url   => '/My/SelectPrinterStation?section=GoodsIn&subsection=ItemCount&force_selection=1',
        };

        $data->{deliveries} =
            $schema->resultset('Public::Delivery')->for_item_count
                unless $handler->{data}{datalite};

        @{$handler->{data}}{keys %{$data}} = values %{$data};
    }

    $handler->{data}{voucher_weight} = config_var( 'Voucher', 'weight' );
    return $handler->process_template;
}

1;

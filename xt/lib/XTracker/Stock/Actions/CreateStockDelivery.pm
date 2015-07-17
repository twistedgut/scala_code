package XTracker::Stock::Actions::CreateStockDelivery;

use strict;
use warnings;

use Log::Log4perl ':easy';
use Try::Tiny;

use XTracker::Document::MeasurementForm;
use XTracker::Document::StockSheet;
use XTracker::Error;
use XTracker::Handler;
use XTracker::Utilities 'unpack_handler_params';
use XTracker::WebContent::StockManagement::Broadcast;

sub handler {
    my $handler = XTracker::Handler->new( shift );
    # unpack request parameters
    my ( $data_ref, $rest_ref ) = unpack_handler_params( $handler->{param_of} );

    LOGCONFESS "No stock_order_id" unless $rest_ref->{stock_order_id};

    my $schema = $handler->schema;
    my $stock_order = $schema->resultset('Public::StockOrder')
            ->find( $rest_ref->{stock_order_id} );

    LOGCONFESS "Stock order $rest_ref->{stock_order_id} not found" if not defined $stock_order;

    my $redirect_uri;
    try {$schema->txn_do(sub{

        # TODO: Move all this up to and including log_stock_in into the model
        # as a sub on Result::Public::StockOrder
        # Create the delivery for the stock order
        my $delivery = $stock_order->create_delivery();

        # Only create a delivery item if it has input (i.e. there's no part
        # delivery in another delivery)
        $delivery->create_delivery_item( $_, $data_ref->{$_->id}{count} || 0 )
            for grep { exists $data_ref->{$_->id} }
                $stock_order->stock_order_items->all;

        $delivery->log_stock_in({ operator_id => $handler->operator_id, });

        my $printer_location
            = $handler->operator->operator_preference->printer_station_name
                or die "No printer station selected - please select one\n";
        XTracker::Document::StockSheet->new(delivery_id => $delivery->id)
            ->print_at_location($printer_location);

        my $purchase_order = $stock_order->purchase_order;

        my $product = $stock_order->product;
        if ( $purchase_order->is_product_po ) {

            # Print a measurement form if it's required
            XTracker::Document::MeasurementForm->new(product_id => $product->id)
                ->print_at_location($printer_location)
                    if $product->requires_measuring;

            # Set product arrival date
            $stock_order->product_channel->update({
                arrival_date => $schema->db_now->truncate(to => 'day')
            }) if $stock_order->product_channel->is_first_arrival;

            # send job to Fulcrum saying that product has been delivered
            #
            # The reason we only send this for products (not vouchers) is
            # because this adds things to the watch list in fulrcrum. We should
            # probably change it so that fulcrum decides what to do and we
            # always sent this message (but over AMQ.)
            $handler->create_job( 'Send::Product::Delivered', [{
                product_id => $product->id,
                channel_id => $purchase_order->channel_id,
            }]);
        }

        # Notify anyone who cares about stock levels
        my $broadcast = XTracker::WebContent::StockManagement::Broadcast->new({
            schema      => $schema,
            channel_id  => $purchase_order->channel_id,
        });
        $broadcast->stock_update(
            quantity_change => 0,
            product_id      => $product->id,
            full_details    => 1,
        );
        $broadcast->commit;

        xt_info( "Delivery Registered for PID: ".$product->id);
        $redirect_uri = "/GoodsIn/StockIn";
    })}
    catch {
        xt_warn( "Couldn't create delivery: $_" );
        $redirect_uri = '/GoodsIn/StockIn/PackingSlip?so_id='.$stock_order->id;
    };
    return $handler->redirect_to( $redirect_uri );
}

1;

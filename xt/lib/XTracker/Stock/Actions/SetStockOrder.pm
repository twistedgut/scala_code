package XTracker::Stock::Actions::SetStockOrder;

use strict;
use warnings;

use Carp;

use XTracker::Constants::FromDB qw(
    :stock_order_item_status
    :stock_order_item_type
);
use XTracker::Database::Product qw( set_product_cancelled );
use XTracker::Database::PurchaseOrder qw(
    check_soi_uniq_variant
    check_soi_status
    create_stock_order_item
    set_soi_status
    set_stock_order_cancel_flag
    :stock_order
);
use XTracker::Error;
use XTracker::Handler;
use XTracker::Utilities qw( :edit );
use Data::Dump qw( pp );
use URI;
use XTracker::WebContent::StockManagement::Broadcast;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    my $uri = URI->new('/StockControl/PurchaseOrder/StockOrder');

    # get the stock_order_id we're updating
    my $stock_order_id = $handler->{param_of}{stock_order_id};

    # Return straight away unless we have submitted a $stock_order_id
    return $handler->redirect_to( $uri ) unless $stock_order_id;

    $uri->query_form({so_id => $stock_order_id});

    return $handler->redirect_to($uri) if exists $handler->{no_submit};

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    eval { $schema->txn_do( sub {
        # loop over form fields and process
        foreach my $form_key ( keys %{ $handler->{param_of} } ) {

            # re-open stock order
            if( $form_key =~ m/(reopen)-(\d+)/ && $handler->{param_of}{$form_key} == 1 ){
                my $item_id = $2;
                set_soi_status(
                    $dbh,
                    $item_id,
                    'stock_order_item_id',
                    $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED
                );
            }

            # close stock order
            elsif( $form_key =~ m/(close)-(\d+)/ && $handler->{param_of}{$form_key} == 1 ){
                my $item_id = $2;
                set_soi_status(
                    $dbh,
                    $item_id,
                    'stock_order_item_id',
                    $STOCK_ORDER_ITEM_STATUS__DELIVERED
                );
            }

            # cancel stock order
            elsif( $form_key =~ m/(cancel)-(\d+)/ ){
                my $item_id = $2;
                my $cancel = $handler->{param_of}{$form_key} eq 'on' ? 't' : 'f';
                set_stock_order_item_details( $dbh, {
                    field => 'cancel',
                    value => $cancel,
                    id    => $item_id,
                    type  => 'id',
                });
            }

            # update ordered qty
            elsif( $form_key =~ m/(ordered)-(\d+)/ && $handler->{param_of}{$form_key} > 0 ){
                my $item_id = $2;
                set_ordered_quantity( $dbh, {
                    id       => $item_id,
                    quantity => $handler->{param_of}{$form_key},
                });
                # set the Stock Order Item Status based on the qty change
                set_soi_status(
                    $dbh,
                    $item_id,
                    'stock_order_item_id',
                    check_soi_status( $dbh, $item_id, 'stock_order_item_id' ),
                );
            }

            # add new sizes
            elsif ( $form_key =~ m/(addsize)-(\d+)/ && $handler->{param_of}{$form_key} > 0 ) {
                my $item_id = $2;
                next if (check_soi_uniq_variant($dbh,$stock_order_id,$item_id));
                create_stock_order_item(
                    $dbh,
                    $stock_order_id,
                    { variant_id        => $item_id,
                      status_id         => $STOCK_ORDER_ITEM_STATUS__ON_ORDER,
                      cancel            => 0,
                      quantity          => $handler->{param_of}{$form_key},
                      type_id           => $STOCK_ORDER_ITEM_TYPE__UNKNOWN,
                      original_quantity => $handler->{param_of}{$form_key},
                    }
                );
            }

            # update start shipping window date
            elsif ( $form_key =~ m/start/ ) {
                my $new_start_date = $handler->{param_of}{start_ship_year}
                                   . '-'
                                   . $handler->{param_of}{start_ship_month}
                                   . '-'
                                   . $handler->{param_of}{start_ship_day}
                                   ;
                set_stock_order_details( $dbh, {
                    field => 'start_ship_date',
                    value => $new_start_date,
                    so_id => $stock_order_id,
                });
            }

            # update end shipping window date
            elsif( $form_key =~ m/cancel/ ){
                my $new_cancel_date = $handler->{param_of}{cancel_ship_year}
                                    . '-'
                                    . $handler->{param_of}{cancel_ship_month}
                                    . '-'
                                    . $handler->{param_of}{cancel_ship_day}
                                    ;
                set_stock_order_details( $dbh, {
                    field => 'cancel_ship_date',
                    value => $new_cancel_date,
                    so_id => $stock_order_id,
                });
            }

            # update comments
            elsif( $form_key =~ m/comment/ ){
                set_stock_order_details( $dbh, {
                    field => 'comment',
                    value => $handler->{param_of}{$form_key},
                    so_id => $stock_order_id,
                });
            }
        }

        # sets the cancel flag on the Stock Order Table if all stock
        # order_items have been cancelled
        set_stock_order_cancel_flag( $dbh, $stock_order_id );

        my $stock_order = $schema->resultset('Public::StockOrder')->find( $stock_order_id );
        my $channel_id = $stock_order->purchase_order->channel_id;
        # set so status
        $stock_order->update_status();

        # see if the product channel should be cancelled or un-cancelled -
        # don't do this if we the stock order relates to a voucher
        set_product_cancelled( $dbh, {
            product_id => $stock_order->product_id,
            channel_id => $channel_id,
        }) if $stock_order->product_id;

        # set po status, this will also send stock update messages
        $stock_order->purchase_order->update_status();
    })};

    if( $@ ){
        xt_warn( "Couldn't update stock order: $@" );
    }
    else {
        xt_success( 'Stock order updated successfully.' );
    }
    return $handler->redirect_to( $uri );
}

1;

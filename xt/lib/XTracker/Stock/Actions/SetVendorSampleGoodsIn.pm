package XTracker::Stock::Actions::SetVendorSampleGoodsIn;

use strict;
use warnings;
use Carp;

use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Handler;
use XTracker::PrintFunctions                    qw( print_label );
use XTracker::Constants::FromDB                 qw( :stock_process_type :flow_status );
use XTracker::Database::Delivery                qw( complete_delivery complete_delivery_item create_delivery set_delivery_status set_delivery_item_quantity
                                                                                        set_delivery_item_status get_stock_order_item_id_by_delivery_item_id get_variant_id_by_delivery_item_id
                                                                                        get_delivery_items );
use XTracker::Database::Logging                 qw( log_delivery );
use XTracker::Database::Stock                   qw( insert_quantity update_quantity check_stock_location );
use XTracker::Database::StockProcess    qw( get_process_group_type get_process_group_total get_delivery_id create_stock_process get_process_group_id );
use XTracker::Database::PurchaseOrder   qw( set_stock_order_item_status get_purchase_order );
use XTracker::Utilities                                 qw( url_encode );
use XTracker::Error;

sub handler {

    my $handler     = XTracker::Handler->new( shift );

    my ( $so_id, $type, $id, @delivery, $product_id );
        my $ret_url                     = "";
        my $ret_params          = "";


    if ( scalar keys(%{ $handler->{param_of} }) ) {

        eval {
                        my %soitem_qty;

            $product_id = $handler->{param_of}{product_id};

            foreach my $item ( keys %{ $handler->{param_of} } ) {

                if ( $item eq 'stock_order_id' ) {
                    $so_id = $handler->{param_of}{$item};
                }
                elsif ( $item eq 'type' ) {
                    $type = $handler->{param_of}{$item};
                }
                elsif ( $item eq 'id' ) {
                    $id = $handler->{param_of}{$item};
                }
                else {
                    my ( $action, $soi_id ) = split( /_/, $item );

                    if ( $action eq 'delivered' ) {
                                                if ($handler->{param_of}{$item} > 0) {

                                                        my $delivery_item = {
                                                                stock_order_item_id => $soi_id,
                                                                packing_slip        => 1,
                                                                type_id             => 4,
                                                        };
                                                        push @delivery, $delivery_item;

                                                        $soitem_qty{$soi_id}    = $handler->{param_of}{$item};
                                                }
                    }
                }
            }

            if ( $#delivery >= 0 ) {

                my $schema = $handler->schema;
                my $dbh = $schema->storage->dbh;
                my $guard = $schema->txn_scope_guard;
                my $purchase_order      = get_purchase_order($dbh, $so_id, "stock_order_id")->[0];
                my $channel_id          = $purchase_order->{channel_id};

                my $delivery    = { delivery_type_id => 4, delivery_items => \@delivery, };

                my $delivery_id = create_delivery( $dbh, $delivery );

                set_delivery_status( $dbh, $delivery_id, 'delivery_id', 6 );

                my $group_id    = 0;
                my $variant_id  = 0;

                my $delivery_item_list  = get_delivery_items( $dbh, $delivery_id );

                foreach my $delivery_items ( @{ $delivery_item_list} ) {

                    my $delivery_item_id    = $delivery_items->[0];
                    my $stock_order_item_id = get_stock_order_item_id_by_delivery_item_id( $dbh, $delivery_item_id );
                    my $item_qty                    = $soitem_qty{$stock_order_item_id};
                    my $stock_process_id    = create_stock_process( $dbh, $STOCK_PROCESS_TYPE__MAIN, $delivery_item_id, $item_qty, \$group_id );

                    # we don't send a PreAdvice here, because this part is
                    # not handled by IWS; we will send the PreAdvice when we
                    # transfer these samples into regular stock in the DC

                    complete_delivery( $dbh, { type => 'stock_process', id => $stock_process_id } );

                    set_delivery_item_quantity( $dbh, $delivery_item_id, $item_qty );

                    set_delivery_item_status( $dbh, $delivery_id, 'delivery_item_id', 4 );

                    complete_delivery_item( $dbh, { type => 'stock_process', id => $stock_process_id } );

                    $variant_id     = get_variant_id_by_delivery_item_id( $dbh, $delivery_item_id );

                    if ( check_stock_location( $dbh, {
                        "variant_id"  => $variant_id,
                        "location"    => "Sample Room",
                        "channel_id"  => $channel_id,
                        status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
                    }) > 0 ) {
                        update_quantity( $dbh, {
                            "variant_id"        => $variant_id,
                            "location"          => "Sample Room",
                            "quantity"          => $item_qty,
                            "type"              => "inc",
                            "channel_id"        => $channel_id,
                            current_status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
                        } );
                    }
                    else {
                        insert_quantity( $dbh, { "variant_id"        => $variant_id,
                            "location"          => "Sample Room",
                            "quantity"          => $item_qty,
                            "channel_id"        => $channel_id,
                            initial_status_id   => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
                        } );
                    }

#                   warn "set_stock_order_item_status( dbh, { type => 'stock_order_item_id', id => $stock_order_item_id, status => 3 } );";
                    set_stock_order_item_status( $dbh, { type => 'stock_order_item_id', id => $stock_order_item_id, status => 3 } );

#                   my $process_group_id = get_process_group_id( $dbh, $stock_process_id );
                }

                my $delivery_args = {
                    type_id     => get_process_group_type( $dbh, $group_id ),
                    quantity    => get_process_group_total( $dbh, $group_id ),
                    operator    => $handler->operator_id,
                    action      => 6,
                    delivery_id => $delivery_id,
                    channel_id      => $channel_id
                };

                log_delivery( $dbh, $delivery_args );

                $guard->commit();

                print_label( $dbh, {
                    department_id => $handler->department_id,
                    type          => 'variant_id',
                    id            => $variant_id,
                    print_small   => 1,
                    num_small     => 1,
                });
            }
        };
                if ($@) {
                        $ret_url        = "/StockControl/Sample/SamplesIn";
                        $ret_params     = "?".$type."=".$id;
                        xt_warn($@);
        }
                else {
            if ( $#delivery >= 0 ) {
                                $ret_url        = "/StockControl/Inventory/Overview";
                                $ret_params     = "?".$type."=".$id;
                                xt_success("Goods Booked In");
                        }
                        else {
                                $ret_url        = "/StockControl/Sample/SamplesIn";
                                $ret_params     = "?".$type."=".$id;
                                xt_warn("There were no Delivered Quantites set");
                        }
                }
    }
        else {
                $ret_url        = "/StockControl/Sample/SamplesIn";
        }

    return $handler->redirect_to( $ret_url.$ret_params );
}

1;

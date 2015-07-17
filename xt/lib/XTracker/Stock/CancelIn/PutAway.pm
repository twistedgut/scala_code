package XTracker::Stock::CancelIn::PutAway;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Shipment        qw( :DEFAULT get_cancel_putaway_list );
use XTracker::Database::Address;
use XTracker::Database::Product;
use XTracker::Database::Stock;
use XTracker::Database::Order;
use XTracker::Database::Logging         qw( log_stock );
use XTracker::Database::StockTransfer   qw( get_stock_transfer );
use XTracker::Utilities                 qw( number_in_list );
use XTracker::Constants::FromDB         qw( :shipment_item_status :flow_status );

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{SHIPMENT_ITEM_STATUS__CANCEL_PENDING}=$SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
    $handler->{data}{SHIPMENT_ITEM_STATUS__CANCELLED}=$SHIPMENT_ITEM_STATUS__CANCELLED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__LOST}=$SHIPMENT_ITEM_STATUS__LOST;
    $handler->{data}{SHIPMENT_ITEM_STATUS__UNDELIVERED}=$SHIPMENT_ITEM_STATUS__UNDELIVERED;

    my $schema = $handler->schema;
    my $shipment_id = $handler->{param_of}{"shipment_id"} || undef;


    #my $view    = $handler->{param_of}{'view'} || '';
    $handler->{data}{sku} = $handler->{param_of}{sku} || undef;

    #$handler->{data}{view}  = "HandHeld"        if (uc($view) eq "HANDHELD");


    $handler->{data}{content}       = 'stocktracker/cancelin/putaway.tt';
    $handler->{data}{section}       = 'Stock Control';
    $handler->{data}{subsection}    = 'Cancellations';
    $handler->{data}{subsubsection} = 'Put Away List';
    $handler->{data}{sidenav}       = [ { 'None' =>
        [
            {   title => 'Put Away List',
                url   => "/StockControl/Cancellations",
            },
        ],
    } ];
    delete $handler->{data}{sidenav}        if ( $handler->{data}{handheld} );

    $handler->{data}{form_action}   = '/StockControl/Cancellations';

    if ($shipment_id) {

        # its actually a sku that we've been passed which is ok really
        if ($shipment_id =~ /^\s*\d+-\d+\s*$/) {
            my $sku = $handler->{param_of}{"shipment_id"};
            my $si_rs = $schema->resultset('Public::ShipmentItem')
                ->search_by_sku_and_item_status(
                    $sku, # the regexp above tells us its a sku ;)
                    $SHIPMENT_ITEM_STATUS__CANCEL_PENDING
                );

            # we might have more than one of these to put pack but they
            # can do each one individually
            if ($si_rs and $si_rs->count > 0) {
                my $si = $si_rs->first;

                $shipment_id = $si->shipment_id;
                $handler->{data}{sku} = $sku;

                # find the last location of the sku and suggest it to user
                $handler->{data}->{last_location}
                    = $si->last_location || 'No history';
            } else {
                $handler->{data}{error_msg} = "Cannot find any Cancel Pending items"
                    ." for the sku - $shipment_id";
            }

        }

        if (not $handler->{data}{error_msg}) {
            $handler->{data}{shipment_id}                   = $shipment_id;

            $handler->{data}{ship_info}                     = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
            $handler->{data}{ship_address}                  = get_address_info( $handler->{dbh}, $handler->{data}{ship_info}{shipment_address_id} );
            $handler->{data}{ship_items}                    = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );
            $handler->{data}{ship_info}{shipping_charge}    = d2( $handler->{data}{ship_info}{shipping_charge} );
            $handler->{data}{ship_info}{shipment_total}     = $handler->{data}{ship_info}{shipping_charge};

            # check if customer order
            if ( $handler->{data}{ship_info}{orders_id} ) {
                $handler->{data}{order_info}        = get_order_info( $handler->{dbh}, $handler->{data}{ship_info}{orders_id} );
                $handler->{data}{sales_channel}     = $handler->{data}{order_info}{sales_channel};
            }
            # must be a stock transfer shipment
            else {
                $handler->{data}{stock_transfer_id} = get_shipment_stock_transfer_id( $handler->{dbh}, $handler->{data}{shipment_id} );
                $handler->{data}{stock_transfer}    = get_stock_transfer( $handler->{dbh}, $handler->{data}{stock_transfer_id} );
                $handler->{data}{sales_channel}     = $handler->{data}{stock_transfer}{sales_channel};
            }


            foreach my $ship_item_id ( keys %{ $handler->{data}{ship_items} } ) {

                # Get images for shipment items
                $handler->{data}{ship_items}{$ship_item_id}{image}
                    = XTracker::Image::get_images({
                        product_id => $handler->{data}{ship_items}{$ship_item_id}{product_id},
                        live => 1,
                        schema => $schema,
                    });
                $handler->{data}{ship_items}{$ship_item_id}{unit_price} = d2( $handler->{data}{ship_items}{$ship_item_id}{unit_price} );
                $handler->{data}{ship_items}{$ship_item_id}{tax}        = d2( $handler->{data}{ship_items}{$ship_item_id}{tax} );
                $handler->{data}{ship_items}{$ship_item_id}{duty}       = d2( $handler->{data}{ship_items}{$ship_item_id}{duty} );

                if (number_in_list($handler->{data}{ship_items}{$ship_item_id}{shipment_item_status_id},
                                   $SHIPMENT_ITEM_STATUS__NEW,
                                   $SHIPMENT_ITEM_STATUS__SELECTED,
                                   $SHIPMENT_ITEM_STATUS__PICKED,
                                   $SHIPMENT_ITEM_STATUS__PACKED,
                                   $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                   $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                                   $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                                   $SHIPMENT_ITEM_STATUS__RETURNED,
                                   $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION) ) {

                    $handler->{data}{ship_items}{$ship_item_id}{sub_total}
                        = d2( $handler->{data}{ship_items}{$ship_item_id}{unit_price}
                            + $handler->{data}{ship_items}{$ship_item_id}{tax}
                            + $handler->{data}{ship_items}{$ship_item_id}{duty} );

                    $handler->{data}{ship_info}{shipment_total} += $handler->{data}{ship_items}{$ship_item_id}{sub_total};
                }
                else {
                    $handler->{data}{ship_items}{$ship_item_id}{sub_total}  = "0.00";
                }

                if ($handler->{data}{ship_items}{$ship_item_id}{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING ){
                    $handler->{data}{pending_items}{$handler->{data}{ship_items}{$ship_item_id}{variant_id}}    = $ship_item_id;
                }
            }

            if ($handler->{data}{sku}) {

                 $handler->{data}{variant_id}   = get_variant_by_sku( $handler->{dbh}, $handler->{data}{sku} );

                 if (!$handler->{data}{variant_id} || !$handler->{data}{pending_items}{$handler->{data}{variant_id}}){
                    $handler->{data}{error_msg} = "The SKU entered does not match those waiting to be put away, please check and try again - ".$handler->{data}{sku};
                    $handler->{data}{sku}       = "";
                    $handler->{data}{variant_id}= "";
                 }
                 else {
                    $handler->{data}{locations} = get_located_stock( $handler->{dbh},
                                                                             { type        => 'variant_id',
                                                                               id          => $handler->{data}{variant_id},
                                                                               exclude_iws => 1,
                                                                               exclude_prl => 1
                                                                             },
                                                                             'stock_main'
                                                                           )->{ $handler->{data}{sales_channel} }{ $handler->{data}{variant_id} };
                    $handler->{data}{form_action} = '/StockControl/Cancellations/SetCancelPutAway';
                 }

            }
        }
        else {
            if ( !$handler->{data}{handheld} ) {
                $handler->{data}{list}  = get_cancel_putaway_list($handler->{dbh});
                $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
                $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];
            }
        }
    }
    else {
        if ( !$handler->{data}{handheld} ) {
            $handler->{data}{list}  = get_cancel_putaway_list($handler->{dbh});
            $handler->{data}{css}   = ['/yui/tabview/assets/skins/sam/tabview.css'];
            $handler->{data}{js}    = ['/yui/yahoo-dom-event/yahoo-dom-event.js', '/yui/element/element-min.js', '/yui/tabview/tabview-min.js'];
        }
    }

    $handler->{data}{main_status_id} = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS;
    return $handler->process_template( undef );
}

### Subroutine : d2                             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub d2 {
    my $val = shift;
    my $n = sprintf( "%.2f", $val );
    return $n;
}

1;

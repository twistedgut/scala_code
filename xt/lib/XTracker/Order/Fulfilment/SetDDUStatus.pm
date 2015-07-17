package XTracker::Order::Fulfilment::SetDDUStatus;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Constants::FromDB qw( :shipment_item_status );
use XTracker::Database::Address;
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Image;
use XTracker::Utilities qw( number_in_list );

sub handler {
    my $handler     = XTracker::Handler->new(shift);

    $handler->{data}{SHIPMENT_ITEM_STATUS__CANCEL_PENDING}=$SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
    $handler->{data}{SHIPMENT_ITEM_STATUS__CANCELLED}=$SHIPMENT_ITEM_STATUS__CANCELLED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__LOST}=$SHIPMENT_ITEM_STATUS__LOST;
    $handler->{data}{SHIPMENT_ITEM_STATUS__UNDELIVERED}=$SHIPMENT_ITEM_STATUS__UNDELIVERED;

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{subsection}    = 'DDU Hold';
    $handler->{data}{subsubsection} = 'Set DDU Status';
    $handler->{data}{content}       = 'ordertracker/fulfilment/setddustatus.tt';
    $handler->{data}{js}            = '/javascript/ddu_status.js',

    # back link in left nav
    push @{ $handler->{data}{sidenav}[0]{'None'} },
        { 'title' => 'Back', 'url' => "/Fulfilment/DDU" };

    # id of shipment we're processing from url
    $handler->{data}{shipment_id}  = $handler->{request}->param('shipment_id');

    my $schema = $handler->schema;
    my $dbh = $schema->storage->dbh;

    # get shipment info
    $handler->{data}{order_id}      = get_shipment_order_id( $dbh, $handler->{data}{shipment_id} );
    $handler->{data}{order}         = get_order_info( $dbh, $handler->{data}{order_id} );
    $handler->{data}{sales_channel} = $handler->{data}{order}{sales_channel};
    $handler->{data}{ship_info}     = get_shipment_info( $dbh, $handler->{data}{shipment_id} );
    $handler->{data}{ship_address}  = get_address_info( $dbh, $handler->{data}{ship_info}{shipment_address_id} );
    $handler->{data}{ship_items}    = get_shipment_item_info( $dbh, $handler->{data}{shipment_id} );

    $handler->{data}{ship_info}{shipping_charge} = d2( $handler->{data}{ship_info}{shipping_charge} );
    $handler->{data}{ship_info}{shipment_total}  = $handler->{data}{ship_info}{shipping_charge};

    my $channel = $schema->resultset('Public::LinkOrderShipment')
                         ->search({shipment_id => $handler->{data}{shipment_id}})
                         ->related_resultset('orders')
                         ->related_resultset('channel')
                         ->first;
    foreach my $ship_item_ref ( values %{ $handler->{data}{ship_items} } ) {

        $ship_item_ref->{unit_price} = d2( $ship_item_ref->{unit_price} );
        $ship_item_ref->{tax}        = d2( $ship_item_ref->{tax} );
        $ship_item_ref->{duty}       = d2( $ship_item_ref->{duty} );
        $ship_item_ref->{image}      = shift @{XTracker::Image::get_images({
            product_id => $ship_item_ref->{product_id},
            live => 1, # Assuming anything ordered is live
            size => 'l',
            schema => $schema,
            business_id => $channel->business_id,
        })};

        if (number_in_list($ship_item_ref->{shipment_item_status_id},
                           $SHIPMENT_ITEM_STATUS__NEW,
                           $SHIPMENT_ITEM_STATUS__SELECTED,
                           $SHIPMENT_ITEM_STATUS__PICKED,
                           $SHIPMENT_ITEM_STATUS__PACKED,
                           $SHIPMENT_ITEM_STATUS__DISPATCHED,
                           $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                           $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                           $SHIPMENT_ITEM_STATUS__RETURNED,
                           $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION) ) {
            $ship_item_ref->{sub_total}= d2(
                $ship_item_ref->{unit_price}
              + $ship_item_ref->{tax}
              + $ship_item_ref->{duty}
            );

            $handler->{data}{ship_info}{shipment_total} += $ship_item_ref->{sub_total};
        }
        else {
            $ship_item_ref->{sub_total} = "0.00";
        }
    }
    $handler->{data}{ship_info}{shipment_total}
        = d2( $handler->{data}{ship_info}{shipment_total} );

    return $handler->process_template;
}

sub d2 { return sprintf( '%.2f', shift ); }

1;

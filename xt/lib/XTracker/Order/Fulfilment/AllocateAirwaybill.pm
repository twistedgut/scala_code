package XTracker::Order::Fulfilment::AllocateAirwaybill;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database;
use XTracker::Database::Address;
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Image;

use XTracker::Constants::FromDB qw( :shipment_item_status );
use XTracker::Utilities qw( number_in_list );

sub handler {
    my $r       = shift;
    my $handler = XTracker::Handler->new($r);

    return $handler->redirect_to($handler->printer_station_uri)
        unless $handler->operator->has_location_for_section('airwaybill');

    my $data = $handler->{data};

    $data->{section}    = 'Fulfilment';
    $data->{subsection} = 'Allocate Airwaybill';
    $data->{content}    = 'ordertracker/fulfilment/allocateairwaybill.tt';

    # back link in left nav
    push( @{ $data->{sidenav}[0]{'None'} },
        { 'title' => 'Back', 'url' => "/Fulfilment/Airwaybill" },
        {
            title => 'Set Airwaybill Station',
            url   => '/My/SelectPrinterStation?section=Fulfilment&subsection=Airwaybill&force_selection=1',
        },
    );

    # id of shipment we're processing from url
    $data->{shipment_id} = $handler->{request}->param('shipment_id');

    # need shipment to determine if it is returnable
    my $shipment = $handler->schema->resultset('Public::Shipment')->find($data->{shipment_id});

    # get required shipment info
    $data->{ship_info}                  = get_shipment_info( $handler->{dbh},$data->{shipment_id} );
    $data->{ship_address}               = get_address_info( $handler->{dbh}, $data->{ship_info}{shipment_address_id} );
    $data->{ship_items}                 = get_shipment_item_info( $handler->{dbh}, $data->{shipment_id} );
    $data->{ship_info}{shipping_charge} = _d2( $data->{ship_info}{shipping_charge} );
    $data->{ship_info}{shipment_total}  = $data->{ship_info}{shipping_charge};
    $data->{orders_id}                  = get_shipment_order_id( $handler->{dbh}, $data->{shipment_id} );
    $data->{order_info}                 = get_order_info( $handler->{dbh}, $data->{orders_id} );
    $data->{is_returnable}              = $shipment->is_returnable;

    # set sales channel to display on page
    $data->{sales_channel} = $data->{order_info}{sales_channel};
    # get shipment item info
    foreach my $ship_item_id ( keys %{ $data->{ship_items} } ) {

        # round prices for display
        $data->{ship_items}{$ship_item_id}{unit_price}  = _d2( $data->{ship_items}{$ship_item_id}{unit_price} );
        $data->{ship_items}{$ship_item_id}{tax}         = _d2( $data->{ship_items}{$ship_item_id}{tax} );
        $data->{ship_items}{$ship_item_id}{duty}        = _d2( $data->{ship_items}{$ship_item_id}{duty} );

        # add to sub totals if not cancelled item
        if (number_in_list($data->{ship_items}{$ship_item_id}{shipment_item_status_id},
                           $SHIPMENT_ITEM_STATUS__NEW,
                           $SHIPMENT_ITEM_STATUS__SELECTED,
                           $SHIPMENT_ITEM_STATUS__PICKED,
                           $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                           $SHIPMENT_ITEM_STATUS__PACKED,
                           $SHIPMENT_ITEM_STATUS__DISPATCHED,
                           $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                           $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                           $SHIPMENT_ITEM_STATUS__RETURNED,
                       ) ) {
            $data->{ship_items}{$ship_item_id}{sub_total} = _d2(
                $data->{ship_items}{$ship_item_id}{unit_price}
              + $data->{ship_items}{$ship_item_id}{tax}
              + $data->{ship_items}{$ship_item_id}{duty}
            );
            $data->{ship_info}{shipment_total} += $data->{ship_items}{$ship_item_id}{sub_total};
        }
        else {
            $data->{ship_items}{$ship_item_id}{sub_total} = "0.00";
        }
        # get images for products
        $data->{ship_items}{$ship_item_id}{image} = get_images({
            'product_id' => $data->{ship_items}{$ship_item_id}{product_id},
            'live' => 1,
            'size' => 'l',
            schema => $handler->schema,
        });
    }

    # check DC/carrier for AWB length - used for restricting form field length
    if ( $data->{ship_info}{carrier} eq 'UPS' ) {
        $data->{waybill_length} = 18;
    }
    else {
        $data->{waybill_length} = 10;
    }

    $handler->{data} = $data;
    return $handler->process_template( undef );
}

sub _d2 {
    my $val = shift;
    my $n = sprintf( "%.2f", $val );
    return $n;
}

1;

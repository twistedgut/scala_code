package XTracker::Order::Functions::Shipment::ShipmentView;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Database::Customer;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Invoice;
use XTracker::Database::Return;
use XTracker::Database::StockTransfer       qw( get_stock_transfer );
use XTracker::Image;
use XTracker::Navigation;
use XTracker::Constants::FromDB qw( :shipment_item_status );

use Data::Dumper;

sub handler {
    my $handler = XTracker::Handler->new(shift);

        $handler->{data}{SHIPMENT_ITEM_STATUS__CANCEL_PENDING}=$SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
        $handler->{data}{SHIPMENT_ITEM_STATUS__CANCELLED}=$SHIPMENT_ITEM_STATUS__CANCELLED;
        $handler->{data}{SHIPMENT_ITEM_STATUS__LOST}=$SHIPMENT_ITEM_STATUS__LOST;
        $handler->{data}{SHIPMENT_ITEM_STATUS__UNDELIVERED}=$SHIPMENT_ITEM_STATUS__UNDELIVERED;

    my $department_id = $handler->department_id;
    my $auth_level    = $handler->auth_level;

    my $path_info = $handler->{data}{uri};
    my @levels    = split( /\//, $path_info );

    my $section = $levels[1];
    $section =~ s/([^\b])([A-Z])/$1 $2/g;

    my $subsection = $levels[2];
    $subsection =~ s/([^\b])([A-Z])/$1 $2/g;

    my $shipment_id = $levels[4];

    my $notice_id = $levels[5];

    $handler->{data}{content}       = 'ordertracker/shared/shipmentview.tt';
    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Order View';
    $handler->{data}{url}           = $path_info;
    $handler->{data}{short_url}     = "/$levels[1]/$levels[2]/";

    $handler->{data}{shipping_charge} = d2( $handler->{data}{shipping_charge} );

    my $stock_transfer_id           = get_shipment_stock_transfer_id( $handler->{dbh}, $shipment_id );
    my $stock_transfer              = get_stock_transfer( $handler->{dbh}, $stock_transfer_id );
    $handler->{data}{sales_channel} = $stock_transfer->{sales_channel};

    $handler->{data}{shipment_id}   = $shipment_id;
    $handler->{data}{shipment}      = get_shipment_info( $handler->{dbh}, $shipment_id );
    $handler->{data}{ship_address}  = get_address_info( $handler->{dbh}, $handler->{data}{shipment}{shipment_address_id} );
    $handler->{data}{ship_items}    = get_shipment_item_info( $handler->{dbh}, $shipment_id );

    foreach my $ship_item_id ( keys %{ $handler->{data}{ship_items} } ) {

        $handler->{data}{ship_items}{$ship_item_id}{unit_price} = d2( $handler->{data}{ship_items}{$ship_item_id}{unit_price});
        $handler->{data}{ship_items}{$ship_item_id}{tax}        = d2( $handler->{data}{ship_items}{$ship_item_id}{tax} );
        $handler->{data}{ship_items}{$ship_item_id}{duty}       = d2( $handler->{data}{ship_items}{$ship_item_id}{duty} );

        $handler->{data}{ship_items}{$ship_item_id}{sub_total}  = d2( $handler->{data}{ship_items}{$ship_item_id} {unit_price} + $handler->{data}{ship_items}{$ship_item_id}{tax} + $handler->{data}{ship_items}{$ship_item_id}{duty} );

        if ( $handler->{data}{ship_items}{$ship_item_id}{shipment_item_status_id} != $SHIPMENT_ITEM_STATUS__CANCEL_PENDING || $handler->{data}{ship_items}{$ship_item_id}{shipment_item_status_id} != $SHIPMENT_ITEM_STATUS__CANCELLED ) {
            $handler->{data}{shipment_total}    += $handler->{data}{ship_items}{$ship_item_id}{sub_total};
        }

        $handler->{data}{ship_items}{$ship_item_id}{image}  = get_images({
            product_id => $handler->{data}{ship_items}{$ship_item_id}{product_id},
            live => 1,
            schema => $handler->schema,
        });
    }

    $handler->{data}{shipment_total}    = d2( $handler->{data}{shipment_total} );
    $handler->{data}{notes}             = get_shipment_notes( $handler->{dbh}, $shipment_id );
    $handler->{data}{emails}            = get_shipment_emails( $handler->{dbh}, $shipment_id );
    $handler->{data}{paperwork}         = get_shipment_documents( $handler->{dbh}, $shipment_id );
    $handler->{data}{shipment_log}      = get_shipment_log( $handler->{dbh}, $shipment_id );
    $handler->{data}{shipment_item_log} = get_shipment_item_log( $handler->schema, $shipment_id );

    ### get shipment returns
    $handler->{data}{returns}            = get_shipment_returns( $handler->{dbh}, $shipment_id );

    ### loop through the returns
    foreach my $return_id ( keys %{ $handler->{data}{returns} } ){

        ### get the items in the return
        $handler->{data}{returns}{$return_id}{return_items} = get_return_item_info( $handler->{dbh}, $return_id );

        ### get the return notes
        $handler->{data}{returns}{$return_id}{return_notes} = get_return_notes( $handler->{dbh}, $return_id );

        $handler->{data}{returns}{$return_id}{log}          = get_return_log( $handler->{dbh}, $return_id );

        $handler->{data}{returns}{$return_id}{item_log}     = get_return_items_log( $handler->{dbh}, $return_id );
    }

    push @{ $handler->{data}{sidenav} }, { 'None' => [
                                                    {
                                                        'title' => 'Back',
                                                        'url'   => "/$levels[1]/$levels[2]?rmbrlctn=1"
                                                    }
                                                ] };

    return $handler->process_template( undef );
}


### Subroutine : d2                             ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub d2 {
    my $val = shift // '';
    my $n = sprintf( "%.2f", $val );
    return $n;
}

1;

package XTracker::Order::Functions::Shipment::CancelReshipment;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Shipment;
use XTracker::Database::Order;

use XTracker::Utilities qw( parse_url number_in_list );
use XTracker::Constants::FromDB qw( :department :shipment_type :shipment_item_status );


### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Cancel Re-Shipment';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{content}       = 'ordertracker/shared/cancelreshipment.tt';

    # get order id and shipment id from url
    $handler->{data}{order_id}      = $handler->{request}->param('order_id');
    $handler->{data}{shipment_id}   = $handler->{request}->param('shipment_id');

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );

    # get order info from db
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};

    # shipment id selected
    if ( $handler->{data}{shipment_id} ) {

        # get shipment data from db
        $handler->{data}{shipment}          = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{shipment_item}     = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );

        # flags to indicate what stage shipment is at
        $handler->{data}{packed}        = 0;

        foreach my $item_id ( keys %{ $handler->{data}{shipment_item} } ) {
            if (number_in_list($handler->{data}{shipment_item}{$item_id}{shipment_item_status_id},
                                           $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                           $SHIPMENT_ITEM_STATUS__PACKED,
                                           $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                           $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                                           $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                                           $SHIPMENT_ITEM_STATUS__RETURNED,
                                       ) ) {
                $handler->{data}{packed} = 1;
            }
        }

        if ( $handler->{data}{packed} > 0 ) {
            $handler->{data}{error_msg} = 'Sorry, the shipment has already been packed and cannot be cancelled.  Please process the item as a Dispatch/Return if cancellation is still required.';
        }
    }
    # get list of shipments to select from
    else {
        $handler->{data}{shipments}     = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
    }


    return $handler->process_template( undef );
}

1;

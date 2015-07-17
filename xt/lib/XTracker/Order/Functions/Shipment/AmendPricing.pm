package XTracker::Order::Functions::Shipment::AmendPricing;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Shipment;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::OrderPayment qw( check_order_payment_fulfilled );

use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :department :shipment_item_status );

use vars qw($r $operator_id);

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{SHIPMENT_ITEM_STATUS__NEW}=$SHIPMENT_ITEM_STATUS__NEW;
    $handler->{data}{SHIPMENT_ITEM_STATUS__SELECTED}=$SHIPMENT_ITEM_STATUS__SELECTED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PICKED}=$SHIPMENT_ITEM_STATUS__PICKED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION}=$SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION;

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Amend Pricing';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{content}       = 'ordertracker/shared/amendpricing.tt';

    # get params from url
    $handler->{data}{order_id}      = $handler->{request}->param('order_id');
    $handler->{data}{shipment_id}   = $handler->{request}->param('shipment_id');
    $handler->{data}{action}        = $handler->{request}->param('action');

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );

    # get order info
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};
    $handler->{data}{invoice_address}   = get_address_info( $handler->{dbh}, $handler->{data}{order}{invoice_address_id} );
    $handler->{data}{payment}           = check_order_payment_fulfilled( $handler->{dbh}, $handler->{data}{order_id} );

    # extra access for Distribution & Shipping managers
    $handler->{data}{auth_department} = 0;

    if ($handler->{data}{department_id} == $DEPARTMENT__DISTRIBUTION_MANAGEMENT || $handler->{data}{department_id} == $DEPARTMENT__SHIPPING_MANAGER){
        $handler->{data}{auth_department} = 1;
    }

    # form submitted
    if ( $handler->{request}->param('submit') ) {

        $handler->{data}{shipment}      = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{shipment_item} = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );

        # total difference between current and amended price
        $handler->{data}{total} = 0;

        # work out item price changes
        foreach my $item_id ( keys %{ $handler->{data}{shipment_item} } ) {

            if ( $handler->{request}->param('price_'.$item_id) ){

                if ( $handler->{request}->param('price_'.$item_id) != $handler->{data}{shipment_item}{$item_id}{unit_price} ||
                    $handler->{request}->param('tax_'.$item_id) != $handler->{data}{shipment_item}{$item_id}{tax} ||
                    $handler->{request}->param('duty_'.$item_id) != $handler->{data}{shipment_item}{$item_id}{duty} ){

                    $handler->{data}{amend_item}{$item_id}{price}   = $handler->{request}->param('price_'.$item_id);
                    $handler->{data}{amend_item}{$item_id}{tax}     = $handler->{request}->param('tax_'.$item_id);
                    $handler->{data}{amend_item}{$item_id}{duty}    = $handler->{request}->param('duty_'.$item_id);

                    $handler->{data}{amend_item}{$item_id}{diff_price}  = $handler->{data}{shipment_item}{$item_id}{unit_price} - $handler->{request}->param('price_'.$item_id);
                    $handler->{data}{amend_item}{$item_id}{diff_tax}    = $handler->{data}{shipment_item}{$item_id}{tax} - $handler->{request}->param('tax_'.$item_id);
                    $handler->{data}{amend_item}{$item_id}{diff_duty}   = $handler->{data}{shipment_item}{$item_id}{duty} - $handler->{request}->param('duty_'.$item_id);

                    $handler->{data}{total} += $handler->{data}{amend_item}{$item_id}{diff_price};
                    $handler->{data}{total} += $handler->{data}{amend_item}{$item_id}{diff_tax};
                    $handler->{data}{total} += $handler->{data}{amend_item}{$item_id}{diff_duty};

                }

            }
        }

        # work out shipping changes
        if ( $handler->{request}->param('shipping') != $handler->{data}{shipment}{shipping_charge} ){
            $handler->{data}{amend_item}{shipping}      = $handler->{request}->param('shipping');
            $handler->{data}{amend_item}{diff_shipping} = $handler->{data}{shipment}{shipping_charge} - $handler->{request}->param('shipping');

            $handler->{data}{total} += $handler->{data}{amend_item}{diff_shipping};
        }
    }


    # shipment selected
    if ( $handler->{data}{shipment_id} ) {

        $handler->{data}{shipment}      = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{shipment_item} = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );

    }
    # no shipment selected - get list of shipments on order
    else {

        $handler->{data}{subsubsection} = 'Select Shipment';
        $handler->{data}{shipments}     = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
    }

    return $handler->process_template( undef );
}

1;

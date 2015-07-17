package XTracker::Order::Functions::Shipment::CreateShipment;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Shipment;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::Stock qw( get_saleable_item_quantity get_exchange_variants );
use XTracker::Database::Product;

use XTracker::Image;
use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :shipment_class :shipment_item_status );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {
    ## no critic(ProhibitDeepNests)

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    $handler->{data}{SHIPMENT_ITEM_STATUS__DISPATCHED}=$SHIPMENT_ITEM_STATUS__DISPATCHED;

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Create Shipment';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{content}       = 'ordertracker/shared/createshipment.tt';

    # get order id and shipment id from url
    $handler->{data}{order_id}      = $handler->{request}->param('order_id');
    $handler->{data}{shipment_id}   = $handler->{request}->param('shipment_id');

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );

    # get order info from db
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};
    $handler->{data}{pod}               = check_order_payment( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{invoice_address}   = get_address_info( $handler->{dbh}, $handler->{data}{order}{invoice_address_id} );

    # shipment id defined
    if ( $handler->{data}{shipment_id} ) {

        # get shipment data from db
        $handler->{data}{shipment}          = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{shipment_address}  = get_address_info( $handler->{dbh}, $handler->{data}{shipment}{shipment_address_id} );
        $handler->{data}{shipment_item}     = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        # Get images for shipment items
        for my $shipment_item_id ( keys %{$handler->{data}{shipment_item}} ) {
            $handler->{data}{shipment_item}{$shipment_item_id}{image}
                = XTracker::Image::get_images({
                    product_id => $handler->{data}{shipment_item}{$shipment_item_id}{product_id},
                    live => 1,
                    schema => $handler->schema,
                });
        }
        # items selected
        if ( $handler->{request}->param('submit') ) {

            # shipment class from form - Replacement or Re-Shipment
            $handler->{data}{shipment_class_id} = $handler->{request}->param('shipment_class_id');

            # work out which items are included in new shipment
            foreach my $item_id ( keys %{ $handler->{data}{shipment_item} } ) {
                if ( (defined $handler->{request}->param($item_id)) &&
                        ($handler->{request}->param($item_id) eq 'included') ) {
                    $handler->{data}{items_selected}                = 1;
                    $handler->{data}{new_shipment_items}{$item_id}  = 1;
                }
            }

            # Replacement Shipment - check stock levels for all non-cancelled items
            if ( $handler->{data}{shipment_class_id} == $SHIPMENT_CLASS__REPLACEMENT ){

                foreach my $item_id ( keys %{ $handler->{data}{new_shipment_items} } ) {

                    # get free stock for variant
                    my $free_stock = get_saleable_item_quantity($handler->{dbh}, $handler->{data}{shipment_item}{$item_id}{product_id} );

                    $handler->{data}{shipment_item}{$item_id}{stock_level} = $free_stock->{ $handler->{data}{sales_channel} }{ $handler->{data}{shipment_item}{$item_id}{variant_id} };

                    # variant sold out - get other sizes to offer
                    if ( $handler->{data}{shipment_item}{$item_id}{stock_level} == 0 ){

                        # get other sizes for variant
                        my $alt_sizes = get_exchange_variants($handler->{dbh}, $item_id);

                        # work out what sizes are available
                        foreach my $var_id ( keys %{$alt_sizes} ) {
                            if ( $alt_sizes->{$var_id}{quantity} > 0) {
                                $handler->{data}{shipment_item}{$item_id}{sizes}{$var_id} = $alt_sizes->{$var_id};
                            }
                        }

                    }
                }
            }
        }
    }
    # no shipment id defined - get list of shipments on order
    else {

        $handler->{data}{subsubsection} = 'Select Shipment';
        $handler->{data}{shipments}     = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
    }

    return $handler->process_template( undef );
}

1;

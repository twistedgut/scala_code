package XTracker::Order::Functions::Shipment::LostShipment;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Database::OrderPayment;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :shipment_item_status :renumeration_type );

use vars qw($r $dbh $operator_id);

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
    $handler->{data}{subsubsection} = 'Lost Shipment';
    $handler->{data}{content}       = 'ordertracker/shared/lostshipment.tt';
    $handler->{data}{short_url}     = $short_url;

    # get id of order and shipment we're working on and order data for display
    $handler->{data}{order_id}         = $handler->{request}->param('order_id');
    $handler->{data}{shipment_id}       = $handler->{request}->param('shipment_id');

    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};
    $handler->{data}{invoice_address}   = get_address_info( $handler->{dbh}, $handler->{data}{order}{invoice_address_id} );
    $handler->{data}{channel}           = get_channel_details( $handler->{dbh}, $handler->{data}{order}{sales_channel} );
    $handler->{data}{shipment_info}     = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
    $handler->{data}{shipment_items}    = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "javascript:history.go(-1)" } );

    # if shipment id set get info for shipment
    if ( $handler->{data}{shipment_id} ) {

        # get number of 'active' items in shipment
        $handler->{data}{num_shipment_items} = 0;

        foreach my $shipment_item_id ( keys %{ $handler->{data}{shipment_items} } ) {
            $handler->{data}{shipment_items}{$shipment_item_id}{image}
                = XTracker::Image::get_images({
                    product_id => $handler->{data}{shipment_items}{$shipment_item_id}{product_id},
                    live => 1,
                    schema => $handler->schema,
                });
            if ( $handler->{data}{shipment_items}{$shipment_item_id}{shipment_item_status_id} == $SHIPMENT_ITEM_STATUS__DISPATCHED ){
                $handler->{data}{num_shipment_items}++;
            }
        }

        # items selected for update
        if ( $handler->{request}->param('select_item') ) {

            # refund type selected
            $handler->{data}{refund_type_id} = $handler->{request}->param('refund_type_id');

            $handler->{data}{num_selected_items}   = 0;

            # loop through selected items
            foreach my $form_key ( %{ $handler->{param_of} } ) {
                if ( $form_key =~ m/-/ ) {
                    my ($field_type, $field_id) = split( /-/, $form_key );

                    # item field
                    if ( $field_type eq "item" ) {

                        # item selected for update as 'Lost'
                        if ( $handler->{param_of}{$form_key} == 1 ) {
                            $handler->{data}{selected_items}{ $field_id }{selected} = 1;
                            $handler->{data}{num_selected_items}++;
                        }
                        # item not selected
                        else {
                            $handler->{data}{selected_items}{ $field_id }{selected} = 0;
                        }
                    }
                }
            }


        }

    }
    # no shipment id defined get all shipments on order
    else {

        $handler->{data}{shipments} = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
    }

    return $handler->process_template( undef );
}

1;

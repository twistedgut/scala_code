package XTracker::Order::Functions::Shipment::SizeChange;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Order;
use XTracker::Database::Address;
use XTracker::Database::Shipment;
use XTracker::Database::Stock;
use XTracker::Database::Product;
use XTracker::Database::Channel qw(get_channel_details);

use XTracker::EmailFunctions;
use XTracker::Utilities qw( parse_url number_in_list );
use XTracker::Constants::FromDB qw( :correspondence_templates :shipment_item_status );
use XTracker::Config::Local qw( customercare_email );


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

    $handler->{data}{SHIPMENT_ITEM_STATUS__NEW}=$SHIPMENT_ITEM_STATUS__NEW;
    $handler->{data}{SHIPMENT_ITEM_STATUS__SELECTED}=$SHIPMENT_ITEM_STATUS__SELECTED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PICKED}=$SHIPMENT_ITEM_STATUS__PICKED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION}=$SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION;

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Size Change';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{content}       = 'ordertracker/shared/size_change.tt';

    # get order id and shipment id from url
    $handler->{data}{order_id}      = $handler->{request}->param('order_id');
    $handler->{data}{shipment_id}   = $handler->{request}->param('shipment_id');
    $handler->{data}{status}        = $handler->{request}->param('status');

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );

    # get order info from db
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};
    $handler->{data}{channel}           = get_channel_details( $handler->{dbh}, $handler->{data}{order}{sales_channel} );
    $handler->{data}{pod}               = check_order_payment( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{invoice_address}   = get_address_info( $handler->{dbh}, $handler->{data}{order}{invoice_address_id} );


    # shipment id defined
    if ( $handler->{data}{shipment_id} ) {

        # get shipment info
        $handler->{data}{shipment_info}     = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{shipment_items}    = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );

        foreach my $shipment_item_id ( keys %{ $handler->{data}{shipment_items} } ) {
            # Get images for shipment items
            $handler->{data}{shipment_items}{$shipment_item_id}{image}
                = XTracker::Image::get_images({
                    product_id => $handler->{data}{shipment_items}{$shipment_item_id}{product_id},
                    live => 1,
                    schema => $handler->schema,
                });
            if ( number_in_list($handler->{data}{shipment_items}{$shipment_item_id}{shipment_item_status_id},
                                $SHIPMENT_ITEM_STATUS__NEW,
                                $SHIPMENT_ITEM_STATUS__SELECTED,
                                $SHIPMENT_ITEM_STATUS__PICKED,
                                $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                $SHIPMENT_ITEM_STATUS__PACKED,
                            ) ) {
                $handler->{data}{shipment_items}{$shipment_item_id}{sizes} = get_exchange_variants($handler->{dbh}, $shipment_item_id);
            }
        }

        $handler->{data}{num_changed_items} = 0;

        # items selected for size change
        if ( $handler->{request}->param('select_item') ) {

            # loop through selected items
            foreach my $form_key ( %{ $handler->{param_of} } ) {
                if ( $form_key =~ m/-/ ) {

                    my ($field_type, $field_id) = split( /-/, $form_key );

                    # item field
                    if ( $field_type eq "item" ) {

                        # item selected for cancellation
                        if ( $handler->{param_of}{$form_key} == 1 ) {
                            # flag item to be changed
                            $handler->{data}{changed_items}{ $field_id }{change} = 1;

                            # get info on what to change to
                            ( $handler->{data}{changed_items}{ $field_id }{change_to_id}, $handler->{data}{changed_items}{ $field_id }{change_to_size}, $handler->{data}{changed_items}{ $field_id }{change_to_sku} ) = split( /_/, $handler->{param_of}{'exch-' . $field_id } );

                            # flag for a stock discrep
                            $handler->{data}{changed_items}{ $field_id }{discrep}= $handler->{param_of}{'discrep-' . $field_id } || 0;

                            # increment no of changed items
                            $handler->{data}{num_changed_items}++;
                        }
                        # item not selected
                        else {
                            $handler->{data}{changed_items}{ $field_id }{change} = 0;
                        }
                    }
                }
            }

            # build a list of old and new sizes for email template
            $handler->{data}{old_size_list} = '';
            $handler->{data}{new_size_list} = '';

            foreach my $id ( keys %{ $handler->{data}{changed_items} } ) {
                if ($handler->{data}{changed_items}{ $id }{change} == 1){
                    $handler->{data}{old_size_list} .= $handler->{data}{shipment_items}{$id}{designer}." ".$handler->{data}{shipment_items}{$id}{name}." Size: ".$handler->{data}{shipment_items}{$id}{designer_size}."\n";
                    $handler->{data}{new_size_list} .= $handler->{data}{shipment_items}{$id}{designer}." ".$handler->{data}{shipment_items}{$id}{name}." Size: ".$handler->{data}{changed_items}{$id}{change_to_size}."\n";
                }
            }

            # get customer email template

            my $shipment_obj = $handler->schema->resultset("Public::Shipment")->find($handler->{data}{shipment_id});

            $handler->{data}{order_number} = $handler->{data}{order}{order_nr};
            $handler->{data}{email_info} = get_and_parse_correspondence_template($handler->schema, $CORRESPONDENCE_TEMPLATES__CHANGE_SIZE_OF_PRODUCT, {
                channel  => $handler->schema->resultset("Public::Channel")->find($handler->{data}{channel}{id}),
                data     => $handler->{data},
                base_rec => $shipment_obj
            });

            $handler->{data}{email_info}{email_to}      = $handler->{data}{shipment_info}{email};
            $handler->{data}{email_info}{email_from}    = customercare_email( $handler->{data}{channel}{config_section}, {
                schema => $handler->schema,
                locale => $shipment_obj->order->customer->locale
            } );
        }

    }
    # no shipment id defined - get list of shipments on order
    else {
        $handler->{data}{shipments} = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
    }

    return $handler->process_template( undef );
}

1;

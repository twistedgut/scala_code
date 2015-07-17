package XTracker::Order::Functions::Shipment::CancelShipmentItem;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Order qw( :DEFAULT get_cancellation_reasons get_cancellation_reason ) ;
use XTracker::Database::OrderPayment qw( check_order_payment_fulfilled );
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Channel qw(get_channel_details);
use XTracker::Config::Local             qw( config_var );

use XTracker::EmailFunctions;
use XTracker::Image;
use XTracker::Utilities qw( parse_url number_in_list );
use XTracker::Constants::FromDB qw(
    :shipment_item_status
    :renumeration_type
    :correspondence_templates
    :flow_status
    :customer_issue_type
);
use XTracker::Config::Local qw( customercare_email );
use XTracker::Database::Stock   qw(
    get_saleable_item_quantity
);

use vars qw($r $dbh $operator_id);

sub handler {
    ## no critic(ProhibitDeepNests)

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Cancel Shipment Item';
    $handler->{data}{content}       = 'ordertracker/shared/cancelshipmentitem.tt';
    $handler->{data}{short_url}     = $short_url;

    $handler->{data}{SHIPMENT_ITEM_STATUS__NEW} = $SHIPMENT_ITEM_STATUS__NEW;
    $handler->{data}{SHIPMENT_ITEM_STATUS__SELECTED} = $SHIPMENT_ITEM_STATUS__SELECTED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PICKED} = $SHIPMENT_ITEM_STATUS__PICKED;
    $handler->{data}{SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION} = $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION;

    # get id of order and shipment we're working on and order data for display
    $handler->{data}{orders_id}         = $handler->{request}->param('orders_id');
    $handler->{data}{shipment_id}       = $handler->{request}->param('shipment_id');
    $handler->{data}{dc_name}           = config_var('DistributionCentre', 'name');

    my $order_obj                       = $handler->schema->resultset('Public::Orders')
                                                            ->find( $handler->{data}{orders_id} );
    my $shipment_obj                    = $handler->schema->resultset('Public::Shipment')
                                                            ->find( $handler->{data}{shipment_id} );

    $handler->{data}{order_obj}         = $order_obj;
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{orders_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};
    $handler->{data}{invoice_address}   = get_address_info( $handler->{dbh}, $handler->{data}{order}{invoice_address_id} );
    $handler->{data}{channel}           = get_channel_details( $handler->{dbh}, $handler->{data}{order}{sales_channel} );
    $handler->{data}{shipment_info}     = get_shipment_info( $handler->{dbh}, $handler->{data}{shipment_id} );
    $handler->{data}{shipment_items}    = get_shipment_item_info( $handler->{dbh}, $handler->{data}{shipment_id} );

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "javascript:history.go(-1)" } );

    # work stuff out for the logic on the page
    $handler->{data}{payment}   = check_order_payment_fulfilled( $handler->{dbh}, $handler->{data}{orders_id} );
    $handler->{data}{packed}    = 0;
    $handler->{data}{pod}       = $order_obj->order_check_payment;

    # check if any shipments on the order are packed yet
    my $shipments = get_order_shipment_info( $handler->{dbh}, $handler->{data}{orders_id} );

    foreach my $shipment_id ( keys %{ $shipments } ){
        $handler->{data}{packed} = check_shipment_packed( $handler->{dbh}, $shipment_id );
    }

    ## find available quantity for incomplete quantity items
    foreach my $si_id (keys %{ $handler->{data}{shipment_items} }){
        my $product_id = $handler->{data}{shipment_items}{$si_id}{product_id};
        my $channel_name = $handler->{data}{channel}{business};
        my $variant_id = $handler->{data}{shipment_items}{$si_id}{variant_id};

        $handler->{data}{shipment_items}{$si_id}{available_quantity} = 0;

        next unless $handler->{data}{shipment_items}{$si_id}{is_incomplete_pick};

        my $available_quantity = get_saleable_item_quantity($handler->{dbh}, $product_id );
        $handler->{data}{shipment_items}{$si_id}{available_quantity} = $available_quantity->{$channel_name}{$variant_id} || 0;
    }

    # if shipment id set get info for shipment
    if ( $handler->{data}{shipment_id} ) {

        # get number of 'active' items in shipment
        $handler->{data}{num_shipment_items} = 0;

        foreach my $shipment_item_id ( keys %{ $handler->{data}{shipment_items} } ) {
            if ( number_in_list($handler->{data}{shipment_items}{$shipment_item_id}{shipment_item_status_id},
                                $SHIPMENT_ITEM_STATUS__NEW,
                                $SHIPMENT_ITEM_STATUS__SELECTED,
                                $SHIPMENT_ITEM_STATUS__PICKED,
                                $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
                                $SHIPMENT_ITEM_STATUS__PACKED,
                            ) ) {
                $handler->{data}{num_shipment_items}++;
            }
            $handler->{data}{shipment_items}{$shipment_item_id}{image}
                = XTracker::Image::get_images({
                    product_id => $handler->{data}{shipment_items}{$shipment_item_id}{product_id},
                    live => 1,
                    schema => $handler->schema,
                });
        }

        # items selected for cancellation
        if ( $handler->{request}->param('select_item') ) {

            $handler->{data}{num_cancelled_items}   = 0;
            $handler->{data}{cancelled_items_list}  = '';
            $handler->{data}{refund_message}        = '';

            # loop through selected items
            foreach my $form_key ( %{ $handler->{param_of} } ) {
                if ( $form_key =~ m/-/ ) {
                    my ($field_type, $field_id) = split( /-/, $form_key );

                    # item field
                    if ( $field_type eq "item" ) {

                        # item selected for cancellation
                        if ( $handler->{param_of}{$form_key} == 1 ) {
                            $handler->{data}{cancelled_items}{ $field_id }{cancel} = 1;
                            $handler->{data}{num_cancelled_items}++;
                            $handler->{data}{cancelled_items_list} .= " - $handler->{data}{shipment_items}{$field_id}{designer} $handler->{data}{shipment_items}{$field_id}{name}\n";
                        }
                        # item not selected
                        else {
                            $handler->{data}{cancelled_items}{ $field_id }{cancel} = 0;
                        }
                    }

                    # reason field
                    if ( $field_type eq "reason" ) {
                        $handler->{data}{cancelled_items}{ $field_id }{reason_id}  = $handler->{param_of}{$form_key};
                        $handler->{data}{cancelled_items}{ $field_id }{reason}     = get_cancellation_reason( $handler->{dbh}, $handler->{param_of}{$form_key} );
                    }
                }
            }

            # refund type selected
            $handler->{data}{refund_type_id} = $handler->{request}->param('refund_type_id');

            # refund message for email template
            $handler->{data}{refund_message} = '';

            # card refund
            if ($handler->{data}{refund_type_id} == $RENUMERATION_TYPE__CARD_REFUND){
                $handler->{data}{refund_message} = "We will shortly email you to confirm the refund to your credit card.\n\n";
            }
            # store credit
            elsif ($handler->{data}{refund_type_id} == $RENUMERATION_TYPE__STORE_CREDIT) {
                $handler->{data}{refund_message} = "We will email you once the store credit has been applied to your account.\n\n";
            }

            # for use in the Email template
            $handler->{data}{is_for_pre_order}  = 0;
            if ( $order_obj->has_preorder ) {
                $handler->{data}{is_for_pre_order}  = 1;
                $handler->{data}{pre_order_obj}     = $order_obj->get_preorder;
                $handler->{data}{pre_order_number}  = $handler->{data}{pre_order_obj}->pre_order_number;
            }

            # get info for customer email template
            $handler->{data}{order_number}  = $order_obj->order_nr;
            $handler->{data}{email_info}  = get_and_parse_correspondence_template( $handler->schema, $CORRESPONDENCE_TEMPLATES__CONFIRM_CANCELLED_ITEM, {
                channel     => $order_obj->channel,
                data        => $handler->{data},
                base_rec    => $shipment_obj,
            } );

            $handler->{data}{email_info}{email_to}      = $handler->{data}{shipment_info}{email};
            $handler->{data}{email_info}{email_from}    = customercare_email( $handler->{data}{channel}{config_section}, {
                schema  => $handler->schema,
                locale  => $order_obj->customer->locale,
            } );

        }
        # no items selected - get list of cancellation reasons for use to select
        else {
            $handler->{data}{reasons} = $handler->schema
                ->resultset('Public::CustomerIssueType')
                ->cancellation_reasons
                # The 'Stock discrepancy on one item, cancelled whole order' issue type should only appear on the Cancel
                # Order screen, not the Cancel Shipment Item one, as it's related to the entire order.
                ->search({ id => { '!=' => $CUSTOMER_ISSUE_TYPE__8__STOCK_DISCREPANCY_ON_ONE_ITEM_COMMA__CANCELLED_WHOLE_ORDER } })
                ->html_select_data;
        }

    }
    else {

        $handler->{data}{shipments} = get_order_shipment_info( $handler->{dbh}, $handler->{data}{orders_id} );
    }

    return $handler->process_template( undef );
}

1;

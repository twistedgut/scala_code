package XTracker::Order::Functions::Order::CancelOrder;

use strict;
use warnings;

use XTracker::Handler;
use XTracker::Database::Order qw( :DEFAULT get_cancellation_reason ) ;
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Channel qw(get_channel_details);

use XTracker::EmailFunctions;
use XTracker::Utilities qw( parse_url );
use XTracker::Constants::FromDB qw( :renumeration_type :correspondence_templates );
use XTracker::Config::Local qw( customercare_email );

### Subroutine : handler                        ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# tt-template  :                                  #
# tt-variables :                                  #

sub handler {

    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    my $schema      = $handler->{schema};

    # get section and sub-section out of URL
    my ($section, $subsection, $short_url) = parse_url($r);

    $handler->{data}{section}       = $section;
    $handler->{data}{subsection}    = $subsection;
    $handler->{data}{subsubsection} = 'Cancel Order';
    $handler->{data}{content}       = 'ordertracker/shared/cancelorder.tt';

    # get id of order we're working on and order data for display
    $handler->{data}{orders_id}         = $handler->{request}->param('orders_id');
    my $order                           = $schema->resultset('Public::Orders')->find( $handler->{data}{orders_id} );
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{orders_id} );
    $handler->{data}{channel}           = get_channel_details( $handler->{dbh}, $handler->{data}{order}{sales_channel} );
    $handler->{data}{invoice_address}   = get_address_info( $handler->{dbh}, $handler->{data}{order}{invoice_address_id} );
    $handler->{data}{shipments}         = get_order_shipment_info( $handler->{dbh}, $handler->{data}{orders_id} );

    $handler->{data}{reasons}           = $schema->resultset('Public::CustomerIssueType')->cancellation_reasons->html_select_data;

    $handler->{data}{from_email}        = customercare_email( $handler->{data}{channel}{config_section}, {
        schema  => $schema,
        locale  => $order->customer->locale,
    } );

    # form submit url's
    $handler->{data}{form_submit_1} = "$short_url/CancelOrder";
    $handler->{data}{form_submit_2} = "$short_url/ChangeOrderStatus?order_id=$handler->{data}{orders_id}&action=Cancel";

    # work stuff out for the logic on the page
    $handler->{data}{refund} = 0;   # flag to determnine if refund required (store credit or voucher credit only)
    $handler->{data}{packed} = 0;   # flag to determine if items packed yet
    $handler->{data}{pod}    = $order->order_check_payment;

    # work out packed status of shipments in order
    foreach my $shipment_id ( keys %{ $handler->{data}{shipments} } ){

        $handler->{data}{packed} = check_shipment_packed( $handler->{dbh}, $shipment_id );

        # flag is credit used
        # GV: commented out to use 'orders.tender' records instead
        #if ( $handler->{data}{shipments}->{$shipment_id}{store_credit} < 0 ) {
        #    $handler->{data}{refund} = 1;
        #}
    }

    # GV: work out if there are any Store Credit or Voucher Credit tenders for the order
    if ( $order->store_credit_tender || $order->voucher_tenders->count ) {
        $handler->{data}{refund}    = 1;
    }

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "$short_url/OrderView?order_id=$handler->{data}{orders_id}" } );

    # set sales channel to display on page
    $handler->{data}{sales_channel} = $handler->{data}{order}{sales_channel};



    # form submitted - reason for cancellation selected
    if ($handler->{request}->param('cancel_reason_id')){

        # cancellation reason
        $handler->{data}{cancel_reason_id}   = $handler->{request}->param('cancel_reason_id');
        $handler->{data}{cancel_reason}      = get_cancellation_reason( $handler->{dbh}, $handler->{data}{cancel_reason_id} );

        # refund type
        ($handler->{data}{refund_type_id}, $handler->{data}{refund_type}) = split(/-/, $handler->{request}->param('refund_type_id'));

        # refund message for email template - default is no refund and empty message
        $handler->{data}{refund_message}     = "";

        # credit refund selected
        if ($handler->{data}{refund_type_id} == $RENUMERATION_TYPE__STORE_CREDIT){
            $handler->{data}{refund_message} = "Our Accounting Department will email you to confirm the store credit available to you shortly.\n\n";
        }
        # card refund selected
        elsif ($handler->{data}{refund_type_id} == $RENUMERATION_TYPE__CARD_REFUND){
            $handler->{data}{refund_message} = "Our Accounting Department will email you to confirm the refund onto your credit card as soon as possible.\n\n";
        }

        # for use in the Email template
        $handler->{data}{is_for_pre_order}  = 0;
        if ( $order->has_preorder ) {
            $handler->{data}{is_for_pre_order}  = 1;
            $handler->{data}{pre_order_obj}     = $order->get_preorder;
            $handler->{data}{pre_order_number}  = $handler->{data}{pre_order_obj}->pre_order_number;
        }

        # add useful Schema Objects
        $handler->{data}{order_obj}    = $order;
        $handler->{data}{shipment_obj} = $order->get_standard_class_shipment;

        # add payment details
        $handler->{data}{payment_info} = $handler->{data}{shipment_obj}->get_payment_info_for_tt;

        $handler->{data}{order_number} = $order->order_nr;
        $handler->{data}{email_info} = get_and_parse_correspondence_template( $schema, $CORRESPONDENCE_TEMPLATES__CONFIRM_CANCELLED_ORDER, {
            channel     => $order->channel,
            data        => $handler->{data},
            base_rec    => $order,
        } );


    }

    return $handler->process_template( undef );
}



1;

package XTracker::Order::Functions::Shipment::HoldShipment;

use strict;
use warnings;
use DateTime;

use XTracker::Database::Order       qw( get_order_info );
use XTracker::Database::Shipment    qw( get_shipment_info get_order_shipment_info get_shipment_hold_info );
use XTracker::Constants::FromDB     qw( :shipment_status );
use XTracker::Handler;
use XTracker::Utilities             qw( parse_url );
use XTracker::Constants             qw/ $APPLICATION_OPERATOR_ID /;

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
    $handler->{data}{subsubsection} = 'Hold Shipment';
    $handler->{data}{short_url}     = $short_url;
    $handler->{data}{content}       = 'ordertracker/shared/holdshipment.tt';
    $handler->{data}{js} = '/javascript/third_party_payment_refresh.js';

    # get order id and shipment id from url
    $handler->{data}{order_id}      = $handler->{request}->param('order_id');
    $handler->{data}{shipment_id}   = $handler->{request}->param('shipment_id');

    # back link in left nav
    push(@{ $handler->{data}{sidenav}[0]{'None'} }, { 'title' => 'Back', 'url' => "$short_url/OrderView?order_id=$handler->{data}{order_id}" } );

    # get order info from db
    $handler->{data}{order}             = get_order_info( $handler->{dbh}, $handler->{data}{order_id} );
    $handler->{data}{sales_channel}     = $handler->{data}{order}{sales_channel};


    # shipment id defined
    if ( $handler->{data}{shipment_id} ) {
        # get shipment data from db
        $handler->{data}{shipment}  = get_shipment_info(         $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{info}      = get_shipment_hold_info(    $handler->{dbh}, $handler->{data}{shipment_id} );
        $handler->{data}{reasons}   = $handler->schema->resultset('Public::ShipmentHoldReason')
                                                        ->get_reasons_for_hold_page( $handler->iws_rollout_phase );

        my $shipment_obj = $handler->schema->resultset('Public::Shipment')->find( $handler->{data}{shipment_id} );

        $handler->{data}{no_edit} = 0;

        # If Shipment is already on 'Finance Hold' or 'DDU hold', dont allow to hold shipment.
        if( $shipment_obj->is_on_finance_hold or $shipment_obj->is_on_ddu_hold ) {
            $handler->{data}{no_edit} = 1;
        }

        unless (
            defined ( $handler->{data}{info}{release_day} )     &&
            defined ( $handler->{data}{info}{release_month} )   &&
            defined ( $handler->{data}{info}{release_year} )    &&
            defined ( $handler->{data}{info}{release_hour} )    &&
            defined ( $handler->{data}{info}{release_minute} ) ) {

            my $dt = DateTime->now( time_zone => "local" );

            $handler->{data}{info}{release_day}      = $dt->day;
            $handler->{data}{info}{release_month}    = $dt->month;
            $handler->{data}{info}{release_year}     = $dt->year;
            $handler->{data}{info}{release_hour}     = '00';
            $handler->{data}{info}{release_minute}   = '00';
        }

        if ( my $reason_id = $handler->{data}{info}{shipment_hold_reason_id} ) {
            # can't use '$handler->{data}{reasons}' because it might not have ALL available Reasons
            my $hold_reason = $handler->schema->resultset('Public::ShipmentHoldReason')->find( $reason_id );
            $handler->{data}{info}{hold_reason_rec} = $hold_reason;

            # only show the menu option if the Reason can be Released Manually
            push @{ $handler->{data}{sidenav}[0]{'None'} }, {
                'title' => 'Release Shipment',
                'url' => "$short_url/ChangeShipmentStatus?action=Release&order_id=$handler->{data}{order_id}&shipment_id=$handler->{data}{shipment_id}"
            } if ( $hold_reason->manually_releasable && !$handler->{data}{no_edit} );
        }
    }
    # no shipment id defined - get list of shipments on order
    else {
        $handler->{data}{shipments} = get_order_shipment_info( $handler->{dbh}, $handler->{data}{order_id} );
    }

    return $handler->process_template( undef );
}

1;

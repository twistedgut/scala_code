package XTracker::Order::Fulfilment::ShipmentsList;

use strict;
use warnings;

=head1 NAME

XTracker::Order::Fulfilment::ShipmentsList - retrieves the list of shipments
per channel that are on hold

Fulfilment/InvalidShipments/RetryValidation will revalidate the address for all
shipments that are currently on hold for an incomplete address.

The validation attempts are terminated if the validation from the external validation service
takes longer than <$timeout_in_seconds> on <$max_timeouts_allowed> occasions.

=cut


use XTracker::Handler;
use XTracker::Constants::FromDB         qw(
    :department
);
use XTracker::Config::Local             qw( :carrier_automation config_var );
use Time::HiRes qw( time );
use XTracker::Error qw( xt_warn xt_success );

sub handler {
    my $r           = shift;
    my $handler     = XTracker::Handler->new($r);

    # split-up URI path to determine which mode we are in: Invalid Shipments or Manual Shipments
    my @levels  = split /\//, $handler->{data}{uri};

    if ( $levels[3] && $levels[3] eq 'RetryValidation' ){
        # variables required to check for address validation timeouts
        # if there are more than $max_timeouts_allowed, the sub will terminate
        my $number_of_timeouts = 0;
        my $max_timeouts_allowed = 3;
        my $timeout_in_seconds = 15;

        my $invalid_shipments = $handler->{schema}->resultset('Public::Shipment')->invalid_shipments_rs();
        while ( my $shipment = $invalid_shipments->next ) {
            next unless $shipment->is_on_hold;
            if ( $number_of_timeouts >= $max_timeouts_allowed ) {
                xt_warn("Address validations have been terminated due to the high number of timeouts in accessing the address validation service.
                 Please try again later.");
                last;
            }
            my $start_validate = time();
            $shipment->retry_address_validation($handler->operator_id);
            xt_success( $shipment->id . " is released from hold." ) unless $shipment->is_on_hold;
            my $end_validate = time();
            $number_of_timeouts++ if ($end_validate - $start_validate) > $timeout_in_seconds;
        }
    }

    $handler->{data}{section}       = 'Fulfilment';
    $handler->{data}{content}       = 'ordertracker/fulfilment/invalid_shipments.tt';
    $handler->{data}{uri_sections}  = \@levels;
    $handler->{data}{colspan}       = config_var('Fulfilment', 'invalid_shipments_colspan');

    unless ( $handler->{data}{datalite} ) {
        $handler->{data}{shipments}     = $handler->{schema}->resultset('Public::Shipment')->invalid_shipments();
    }

    if ( $levels[2] eq "InvalidShipments" ) {
        $handler->{data}{subsection}    = 'Invalid Shipments';
        $handler->{data}{table_heading} = 'Shipments that have failed Address Validation';
        if ( config_var( 'UPS', 'enabled' ) ) {
            # get the Address Quality Rating Threshold for each channel
            foreach ( keys %{ $handler->{data}{shipments} } ) {
                $handler->{data}{qrt}{$_}   = get_ups_qrt( $handler->{data}{channel_config}{$_} ) * 100;
            }
        }
    }

    # check if user is in the right department to use the 'Edit Shipment' page
    $handler->{data}{can_edit_shipment} =  ( $handler->{data}{department_id} =~ /^(
                                               $DEPARTMENT__SHIPPING|
                                               $DEPARTMENT__SHIPPING_MANAGER|
                                               $DEPARTMENT__CUSTOMER_CARE|
                                               $DEPARTMENT__CUSTOMER_CARE_MANAGER|
                                               $DEPARTMENT__DISTRIBUTION_MANAGEMENT|
                                               $DEPARTMENT__STOCK_CONTROL)$/x );

    # check if user is in the right department to use the 'Retry All Shipments' button
    $handler->{data}{can_retry_all_shipments} = ( $handler->{data}{department_id} == $DEPARTMENT__SHIPPING_MANAGER );

    return $handler->process_template( undef );
}

1;

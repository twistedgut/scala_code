package XTracker::Order::Actions::UpdateShipmentAirwaybill;

use strict;
use warnings;

use Try::Tiny;

use XTracker::Constants::FromDB qw( :shipment_type );
use XTracker::Error;
use XTracker::Handler;
use XTracker::Order::Printing::ShipmentDocuments qw( generate_paperwork );
use XTracker::PrinterMatrix;

use XTracker::Document::OutwardProforma;

sub handler {
    my $handler     = XTracker::Handler->new( shift );
    my $schema = $handler->schema;

    my $shipment_id  = $handler->{param_of}{shipment_id};
    my $outbound_awb = $handler->{param_of}{out_airway} || 'none';
    my $return_awb   = $handler->{param_of}{ret_airway} || 'none';
    my $shipment     = $schema->resultset('Public::Shipment')->find($shipment_id);
    my $redirect     = '/Fulfilment/Airwaybill';
    my $msg = '';

    unless ( $shipment_id ) {
        xt_warn( 'No shipment_id passed to set airwaybills' );
        return $handler->redirect_to( $redirect )
    }

    # airwaybill number entered by user
    if ( is_awb_set($outbound_awb) || is_awb_set($return_awb) ) {
        if (
            !is_awb_set($outbound_awb)
         || ($shipment->is_returnable && !is_awb_set($return_awb))
        ) {
            $redirect .= "/AllocateAirwaybill?shipment_id=$shipment_id";
        }
        try {
            _update_airwaybill( $shipment, $outbound_awb, $return_awb, $handler->operator );
        }
        catch {
            xt_warn( "There was an error trying to update awbs for shipment $shipment_id: $_" );
        };
        return $handler->redirect_to( $redirect )
    }

    # If we get here it means airwaybills are empty - reset them to 'none'
    $shipment->clear_airwaybills;
    xt_success( 'AWB removed from shipment.' );

    return $handler->redirect_to( $redirect )
}

sub _update_airwaybill {
    my ( $shipment, $outbound_awb, $return_awb, $operator ) = @_;

    my $schema = $shipment->result_source->schema;
    $schema->txn_do(sub{
        $shipment->update_airwaybills( $outbound_awb, $return_awb );

        # Process paperwork for DHL ORDERS
        return if $shipment->is_premier;

        # BOTH airways allocated - print out proforma invoice & sales invoice
        # OR print the forms if the shipment is not returnable and there is no return AWB
        my $ret_awb_okay = !($shipment->is_returnable xor is_awb_set($return_awb));

        # Return if the outbound and return awbs aren't both ok
        unless ( is_awb_set($outbound_awb) && $ret_awb_okay ) {
            xt_success( 'AWB updated successfully.' );
            return;
        }

        # Print shipment paperwork
        my $location = ( $operator->operator_preference )
            ? $operator->operator_preference->printer_station_name
            : undef;

        if ( $location ) {
            generate_paperwork({
                dbh                      => $schema->storage->dbh,
                shipment                 => $shipment,
                location                 => $location,
                no_print_invoice_if_gift => 1,
            });
        } else {
            die 'No printer location provided for the Airwaybill section!';
        }

        xt_success( 'Shipping paperwork printed.' );
    });
}

sub is_awb_set { $_[0] ne 'none'; }

1;

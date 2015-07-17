package XTracker::Order::Printing::PremierDeliveryNote;

use strict;
use warnings;
use Perl6::Export::Attrs;

use XTracker::Database;
use XTracker::XTemplate;
use XTracker::PrintFunctions;
use XTracker::Database::Order;
use XTracker::Database::Shipment;
use XTracker::Database::Customer;
use XTracker::Database::Address;
use XTracker::Database::Finance;
use XTracker::Constants::FromDB qw( :shipment_item_status );
use XTracker::Utilities qw( number_in_list );

use vars qw($r $dbh $operator_id);

### Subroutine : generate_premier_delivery_note  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub generate_premier_delivery_note :Export(:DEFAULT) {

    my ( $dbh, $shipment_id, $printer, $copies ) = @_;

    ### get all info required

    my $data;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    $mon++;
    $year = $year+1900;

    $data->{date} = $mday."/".$mon."/".$year;

    $data->{shipment}     = get_shipment_info( $dbh, $shipment_id );
    $data->{item}     = get_shipment_item_info( $dbh, $shipment_id );
    $data->{order}        = get_order_info( $dbh, $data->{shipment}{orders_id} );
    $data->{customer_notes} = get_customer_notes( $dbh, $data->{order}{customer_id} );
    $data->{shipping_address}        = get_address_info( $dbh, $data->{shipment}{shipment_address_id} );

    ### pre-procseeing on shipment items
    foreach my $id ( keys %{ $data->{item} } ) {

        if (number_in_list($data->{item}{$id}{shipment_item_status_id},
                           $SHIPMENT_ITEM_STATUS__NEW,
                           $SHIPMENT_ITEM_STATUS__SELECTED,
                           $SHIPMENT_ITEM_STATUS__PICKED,
                           $SHIPMENT_ITEM_STATUS__PACKED,
                           $SHIPMENT_ITEM_STATUS__DISPATCHED,
                           $SHIPMENT_ITEM_STATUS__RETURN_PENDING,
                           $SHIPMENT_ITEM_STATUS__RETURN_RECEIVED,
                           $SHIPMENT_ITEM_STATUS__RETURNED,
                           $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION) ) {

            my $sku = $data->{item}{$id}{legacy_sku};

            if ( $data->{shipment_item}{$sku}{name} ){
                $data->{shipment_item}{$sku}{quantity} = $data->{shipment_item}{$sku}{quantity} + 1;
            }
            else {
                $data->{shipment_item}{$sku}{quantity} = 1;
                $data->{shipment_item}{$sku}{name} = $data->{item}{$id}{name};
                $data->{shipment_item}{$sku}{designer} = $data->{item}{$id}{designer};
            }
        }

    }

    ### get Premier Delivery/Collection notes from customer notes
    foreach my $note_id ( keys %{ $data->{customer_notes} } ) {
        if ($data->{customer_notes}{$note_id}{description} eq "Premier Delivery/Collection" ) {
            $data->{note} .= $data->{customer_notes}{$note_id}{note}."<br />";
        }
    }

    my $result = 0;

    $data->{printer_info} = get_printer_by_name( $printer );

    if ( %{$data->{printer_info}||{}} ) {

        my $html = create_document( 'prmdelnote-' . $shipment_id . '',
            'print/premier_delivery_note.tt', $data );

        $result = print_document( 'prmdelnote-' . $shipment_id . '',
            $data->{printer_info}{lp_name}, $copies );

        log_shipment_document(
            $dbh, $shipment_id,
            'Premier Delivery Note',
            'prmdelnote-' . $shipment_id . '',
            $data->{printer_info}{name}
        );

   }

    return $result;

}

1;


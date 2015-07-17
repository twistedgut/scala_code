package XTracker::Order::Printing::PremierReturnNote;

use strict;
use warnings;
use Perl6::Export::Attrs;

use XTracker::Database;
use XTracker::XTemplate;
use XTracker::PrintFunctions;
use XTracker::Database::Order;
use XTracker::Database::Return;
use XTracker::Database::Shipment;
use XTracker::Database::Customer;
use XTracker::Database::Address;
use XTracker::Database::Finance;

use vars qw($r $dbh $operator_id);

### Subroutine : generate_premier_return_note    ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub generate_premier_return_note :Export(:DEFAULT) {

    my ( $dbh, $return_id, $printer, $copies ) = @_;

    ### get all info required

    my $data;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    $mon++;
    $year = $year+1900;

    $data->{date} = $mday."/".$mon."/".$year." ".$hour.":".$min;

    $data->{return} = get_return_info( $dbh, $return_id );

    if ($data->{return}{pickup} == 1){
        $data->{pickup} = "Selected";
    }
    else {
        $data->{pickup} = "Anytime";
    }

    $data->{shipment}     = get_shipment_info( $dbh, $data->{return}{shipment_id} );
    $data->{shipment_item}     = get_shipment_item_info( $dbh, $data->{return}{shipment_id} );
    $data->{order}        = get_order_info( $dbh, $data->{shipment}{orders_id} );
    $data->{shipping_address} = get_address_info( $dbh, $data->{shipment}{shipment_address_id} );
    $data->{customer} = get_customer_info( $dbh, $data->{order}{customer_id} );
    $data->{customer_notes} = get_customer_notes( $dbh, $data->{order}{customer_id} );

    $data->{item}     = get_return_item_info( $dbh, $return_id );

    ### pre-procseeing on shipment items
    foreach my $id ( keys %{ $data->{item} } ) {

        my $sku = $data->{item}{$id}{legacy_sku};

        if ( $data->{return_item}{$sku}{name} ){
            $data->{return_item}{$sku}{quantity} = $data->{return_item}{$sku}{quantity} + 1;
        }
        else {
            $data->{return_item}{$sku}{quantity} = 1;
            $data->{return_item}{$sku}{name} = $data->{item}{$id}{name};
            $data->{return_item}{$sku}{designer} = $data->{item}{$id}{designer};
            $data->{return_item}{$sku}{shipment_item_id} = $data->{item}{$id}{shipment_item_id};
        }
    }

    ### get Premier Delivery/Collection notes from customer notes
    foreach my $note_id ( keys %{ $data->{customer_notes} } ) {
        if ($data->{customer_notes}{$note_id}{description} eq "Premier Delivery/Collection" ) {
            $data->{note} .= $data->{customer_notes}{$note_id}{note}."<br />";
        }
    }

    # result of print job
    my $result = 0;

    # generate html document
    my $html = create_document( 'prmretnote-' . $return_id . '', 'print/premier_return_note.tt', $data );


    # check if printer defined and print document
    if ( $printer ) {

        # get printer info from name supplied
        $data->{printer_info} = get_printer_by_name( $printer );

        if ( %{$data->{printer_info}||{}} ) {
            $result = print_document( 'prmretnote-' . $return_id . '', $data->{printer_info}{lp_name}, $copies );
        }

    }
    # no printer defined - just return a result of 1 as we don't need to print
    else {
        $result = 1;
    }

    # log print job
    log_shipment_document(
            $dbh,
            $data->{return}{shipment_id},
            'Premier Return Note',
            'prmretnote-' . $return_id . '',
            $data->{printer_info}{name} || ''
    );

    return $result;

}

1;


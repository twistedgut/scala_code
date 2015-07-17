package XTracker::Order::Printing::ShipmentDocuments;

use strict;
use warnings;
use Perl6::Export::Attrs;
use File::Basename;

use XTracker::PrintFunctions;
use XTracker::EmailFunctions qw(
                                send_and_log_internal_email
                                send_email
                               );

use XTracker::Config::Local qw( get_shipping_printers email_address_for_setting );

use XTracker::Database                  qw( get_schema_using_dbh );
use XTracker::Database::Shipment;
use XTracker::Database::Address;
use XTracker::Database::Invoice;
use XTracker::Database::Distribution    qw( AWBs_are_present );

use XTracker::Document::DangerousGoodsNote;
use XTracker::Document::Invoice;
use XTracker::Document::ReturnProforma;
use XTracker::Document::OutwardProforma;

use XTracker::Order::Printing::OutwardProforma;
use XTracker::Order::Printing::GiftMessage;
use XTracker::Order::Printing::UPSBoxLabel;

use XTracker::DHL::AWB qw( log_dhl_waybill );
use XTracker::DHL::Label qw(
    create_dhl_label
    get_label_filename
    log_dhl_licence_plate
    maybe_create_saturday_delivery_label
);

use XTracker::Config::Local qw( config_var
                                manifest_level
                                manifest_countries
                                :carrier_automation
                                send_multi_tender_notice_for_country
                                );

use Readonly;
Readonly my $MULTI_TENDER_NOTICE_EMAIL_TEMPLATE
    => 'email/internal/multi_tender_email_notice.tt';

### Subroutine : print_shipment_documents          ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub print_shipment_documents :Export(:DEFAULT) {

    my ( $dbh, $box_number, $document_printer, $label_printer, $no_print_invoice_if_gift )  = @_;

    # get the box ID out of the box number entered
    my ($box_id) = split /-/, $box_number;

    my $shipping_printers = get_shipping_printers( get_schema_using_dbh( $dbh, 'xtracker_schema' ));

    # default both to the first printer if not set
    if (!$label_printer)    { $label_printer    = $shipping_printers->{label}->[0]->{name}   ; }
    if (!$document_printer) { $document_printer = $shipping_printers->{document}->[0]->{name}; }

    # get the shipment id from the box id
    my $shipment_id = get_box_shipment_id($dbh, $box_id)
        or die "Could not find shipment for this box - $box_id";

    # gather shipment data
    my $shipment_data       = get_shipment_info( $dbh, $shipment_id );
    my $shipment_address    = get_address_info( $dbh, $shipment_data->{shipment_address_id} );
    my $boxes               = get_shipment_boxes( $dbh, $shipment_id );
    my $schema              = get_schema_using_dbh($dbh,'xtracker_schema');
    my $shipment            = $schema->resultset('Public::Shipment')->find($shipment_id);

    # check that shipment has a valid destination code
    if ( !$shipment_data->{destination_code} ) {
        die "The shipment does not have a valid DHL Destination Code - please contact the Shipping Department";
    }

    # check that shipment has a return AWB
    if ( $shipment->is_returnable && !AWBs_are_present( { for => 'shipment_docs', on => $shipment_data } ) ) {
        die "The shipment does not have a return AWB assigned, please enter one via the Packing screen.";
    }

    # check that shipment is the correct status of "Processing"
    if ( $shipment_data->{status} ne "Processing" ) {
        die "The shipment is not the correct status for labelling.  Current status: ".$shipment_data->{status};
    }

    # loop count for boxes
    my $box_num = 1;

    # keep track of scanned box number
    my $current_box;

    # loop through shipment boxes
    foreach my $shipment_box_id ( sort {$a cmp $b} keys %{$boxes} ){

        # print label for the box entered
        if ($shipment_box_id eq $box_id){

            # create shipping label code
            my $shipment_label_file_name = create_dhl_label(
                $dbh,
                $shipment_id,
                $box_id,
            );

            die "There was a problem creating the shipping label for box: $box_id\n"
                unless $shipment_label_file_name;

            print_label_and_log(
                $dbh,
                "Shipment",
                $shipment_label_file_name,
                $box_id,
                $shipment_id,
                $label_printer,
            );

            my $saturday_delivery_label_file_name
                = maybe_create_saturday_delivery_label(
                    $shipment,
                    $box_id,
                );
            if($saturday_delivery_label_file_name) {
                print_label_and_log(
                    $dbh,
                    "Saturday Delivery Service Alert",
                    $saturday_delivery_label_file_name,
                    $box_id,
                    $shipment_id,
                    $label_printer,
                );
            }

            ### keep track of which number box out of the shipment we're processing
            $current_box = $box_num;
        }

        $box_num++;
    }

    ### print off paperwork if its the first box in the shipment
    if ($current_box == 1) {
        # DCS-1213: moved printing paperwork into new function
        generate_shipment_paperwork( $dbh, {
                                        shipment_id     => $shipment_id,
                                        shipping_country=> $shipment_address->{country},
                                        doc_printer     => $document_printer,
                                        no_print_invoice_if_gift => ( defined $no_print_invoice_if_gift ? 1 : 0 ),
                                } );
        # WHM-3293: use DHL XMLPI service to generate labels and archive document
        if ( $shipment->requires_archive_label ) {
        my $shipment_archive_doc = get_label_filename($shipment->id . "_archive_file.lbl");
        print_label_and_log(  $dbh,
                              "Shipment Archive Document",
                              $shipment_archive_doc,
                              $box_id,
                              $shipment_id,
                              $label_printer,
                           );
        }
        ### gift message notice - if required
        $shipment->print_gift_message_warnings($document_printer)
            if $shipment->requires_gift_message_warning;
    }
    ### send email to shipping department if sending to US from DC1 and shipment contains fish/wildlife products
    if ($shipment_data->{type} eq "International" && $shipment_address->{country} eq "United States") {

        if (check_fish_wildlife_restriction($dbh, $shipment_id)) {
            send_email( config_var('Email', 'xtracker_email'), config_var('Email', 'xtracker_email'), config_var('Email', 'shipping_email'), "US shipment containing a Fish & Wildlife item", "\nShipment: $shipment_id\n\n" );
        }
    }

    return $shipment_id;
}

sub print_label_and_log {
    my ($dbh, $label_description, $label_file_name, $box_id, $shipment_id, $label_printer) = @_;

    my $printer_info = get_printer_by_name( $label_printer );
    XT::LP->print({
        printer  => $printer_info->{lp_name},
        filename => $label_file_name,
        copies   => 1,
    }) or die "Could not print $label_description Label for box_id($box_id), shipment_id($shipment_id)\n";

    my $label_file_basename = basename($label_file_name);
    log_shipment_document(
        $dbh,
        $shipment_id,
        "$label_description Label",
        $label_file_basename,
        $label_printer,
    );
}

=head2 generate_shipment_paperwork

  usage        : generate_shipment_paperwork( $dbh, {
                            shipment_id     => $shipment_id,
                            shipping_country=> $shipment_country,
                            packing_station => $packing_station_name     # Optional
                    } );

  description  : This prints out all the paperwork needed for a Non-Premier shipment such as Outward Proforma, Returns Proforma & Sales Invoice.
                 It takes a shipment id and shipping country and also a operator's packing station if available, it then prints all the paperwork
                 to the packing station's document printer. If no packing station is supplied then the default 'Shipping' printer will be used.

  parameters   : A Database Handler, A HASH of Args Containing: Shipment Id, Shipment Country & Packing Station Name (which is optional).
  returns      : Nothing.
  todo         : remove after porting all printers. Use generate_paperwork

=cut

sub generate_shipment_paperwork :Export() {

    my ( $dbh, $args )      = @_;

    die "No Database Handle"            if ( !$dbh );
    die "No Arguments Passed"           if ( !$args );
    die "No Shipment Id Passed"         if ( !$args->{shipment_id} );
    die "No Shipping Country Passed"    if ( !$args->{shipping_country} );

    my $doc_printer     = $args->{doc_printer}      || "";
    my $lab_printer     = $args->{lab_printer}      || "";

    # get schema for system config settings
    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    if ( !get_shipment_info( $dbh, $args->{shipment_id} ) ) {
        die "No Shipment found for Shipment Id: ".$args->{shipment_id};
    }
    if ( $args->{packing_station} ) {

        # get the document printer for the Packing Station
        my $ps_printers = get_packing_station_printers( $schema, $args->{packing_station} );
        $doc_printer    = $ps_printers->{document};
        $lab_printer    = $ps_printers->{label};

        die "Can't Find a Document Printer for Packing Station: ".$args->{packing_station}
            if ( !$doc_printer );
        die "Can't Find a Label Printer for Packing Station: ".$args->{packing_station}
            if ( !$lab_printer );
    }
    die "No Document Printer Specified"         if ( !$doc_printer );

    # if we have a label printer then see about
    # printing any UPS box labels if required
    if ( $lab_printer ) {
        print_ups_box_labels( $dbh, $args->{shipment_id}, $lab_printer );
    }

    # get shipment dbic resultset
    my $shipment = $schema->resultset('Public::Shipment')
                          ->find($args->{shipment_id});

    my $num_proforma        = 4;
    my $num_returns_proforma= 4;

    ( $num_proforma, $num_returns_proforma )
        = check_country_paperwork($dbh, $args->{shipping_country});

    # PRINT proforma
    if ( $num_proforma > 0 ) {
        generate_outward_proforma($dbh, $args->{shipment_id}, $doc_printer, $num_proforma, $schema);
    }

   #  # dgn = dangerous goods note
   #  # for DC1 only if shipment is_hazmat_lq
    if ( $shipment->requires_dangerous_goods_note ) {
        $shipment->generate_dgn_paperwork({
            printer => $doc_printer,
            copies  => 1
        });
   }

    # PRINT returns proforma
    if ( $num_returns_proforma > 0 && $shipment->is_returnable ) {
        $shipment->generate_return_proforma({
            printer => $doc_printer,
            copies  => $num_returns_proforma,
        });
    }

    # PRINT sales invoice
    # Do not print invoice for payment methods like Klarna
    if ($shipment->should_print_invoice) {
        my $renumeration = $shipment->get_sales_invoice;
        if ( $renumeration ) {
            $renumeration->generate_invoice({
                printer => $doc_printer,
                copies  => 1,
                no_print_if_gift => $args->{no_print_invoice_if_gift},
            });
        }
    }

    # Fetch klarna invoice if necessary
    _fetch_klarna($shipment);

    # Notify shipping dept
    _notify_shipping_dep($shipment, $dbh);

    return;
}

=head2 generate_paperwork

  usage        : generate_paperwork({
                        dbh      => $dbh
                        shipment => $shipment,
                        location => $location #printer location
                        no_print_invoice_if_gift => 1 #optional
                });

  description  : This prints out all the paperwork needed for airwaybill section:
                    - Invoice
                    - Outward Proforma
                    - Returns Proforms - if needed
                    - Dangerous Goods Note

  parameters   : A HASH of Args Containing: Shipment , Shipment Country & Packing Station Name (which is optional).
  returns      : Nothing.
  todo         : remove after porting all printers. Use generate_paperwork

=cut

sub generate_paperwork : Export() {
    my $args = shift;

    my $dbh = delete $args->{dbh}
        or die "No Database Handle";

    my $shipment = delete $args->{shipment}
        or die "No shipment provided to generate paperwork";

    my $shipping_country = $shipment->shipment_address->country
        or die "No Shipping Country Passed";

    my $location = delete $args->{location};

    my ( $num_proforma, $num_returns_proforma ) = ( 4, 4 );

    ( $num_proforma, $num_returns_proforma )
        = check_country_paperwork($dbh, $shipment->shipment_address->country);

    # Print Outward Proforma
    if ( $num_proforma > 0 ) {
        my $doc = XTracker::Document::OutwardProforma
            ->new( shipment_id => $shipment->id )
            ->print_at_location($location, $num_proforma);
    }

    # Print Return Proforma
    if ( $num_returns_proforma > 0 && $shipment->is_returnable ) {
        my $doc = XTracker::Document::ReturnProforma
            ->new( shipment_id => $shipment->id )
            ->print_at_location($location, $num_returns_proforma);
    }

    #  # dgn = dangerous goods note
    #  # for DC1 only if shipment is_hazmat_lq
     if ( $shipment->requires_dangerous_goods_note ) {
         my $doc = XTracker::Document::DangerousGoodsNote
             ->new( shipment_id => $shipment->id  )
             ->print_at_location( $location, 1 );
    }

    # PRINT sales invoice
    # Do not print invoice for payment methods like Klarna
    if ( $shipment->should_print_invoice && $shipment->get_sales_invoice ) {
        my $doc = XTracker::Document::Invoice
            ->new( shipment_id => $shipment->id );
        if ( $shipment->gift && $args->{no_print_invoice_if_gift} ) {
            $doc->filename();
            $doc->log_document('Generated NOT Printed');
        } else {
            $doc->print_at_location($location);
        }
    }

    # Fetch Klarna invoice if necessary
    _fetch_klarna($shipment);

    # Notify shipping dept
    _notify_shipping_dep($shipment, $dbh);
}

=head2 _fetch_klarna


=cut

sub _fetch_klarna {
    my $shipment = shift;

    my $order = $shipment->order;
    $shipment->fetch_third_party_klarna_invoice
        if ( $order && $order->is_paid_using_the_third_party_psp( 'Klarna' ) );
}

=head2 _notify_shipping_dep

# CANDO-2472 - send email to shipping dept if sending to certain countries
and order was paid with a card and either store credit or voucher

=cut

sub _notify_shipping_dep {
    my ( $shipment, $dbh ) = @_;

    my $order = $shipment->order;

    # get schema for system config settings
    my $schema  = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    my $send_notice_email = send_multi_tender_notice_for_country( $schema, $shipment->shipment_address->country );
    if ( $send_notice_email ) {

        if ( $order && $order->card_debit_tender && ( $order->store_credit_tender || $order->voucher_tenders->count ) ) {

            send_and_log_internal_email(
                data_object => $shipment,
                to          => email_address_for_setting( 'multi_tender_notice_email', $order->channel ),
                subject     => uc($shipment->shipment_address->country)." SHIPMENT WITH DUAL TENDER",
                from_file => { path => $MULTI_TENDER_NOTICE_EMAIL_TEMPLATE },
                stash       => {
                    template_type   => 'email',
                    shipment_id     => $shipment->id,
                }
            );
        }
    }
}

1;

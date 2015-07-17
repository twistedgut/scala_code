package XTracker::DHL::Label;
use strict;
use warnings;

use XTracker::Database           qw( get_schema_using_dbh );
use XTracker::Database::Utilities;
use XTracker::Database::Shipment qw( check_tax_included check_fish_wildlife_restriction );
use XTracker::Database::Currency qw( get_local_conversion_rate get_currency_by_id );
use XTracker::Error;
use XTracker::Logfile qw(xt_logger);
use XTracker::XTemplate;
use XTracker::DBEncode qw( decode_db );
use XTracker::ShippingGoodsDescription qw( description_of_goods );
use Perl6::Export::Attrs;
use XTracker::Config::Local qw( dhl_xmlpi config_var );
use XTracker::DHL::XMLDocument;
use XTracker::DHL::XMLRequest;
use MooseX::Params::Validate;
use Carp qw( croak );
use Data::Dump qw/pp/;
use MIME::Base64;
use Try::Tiny;

# Subroutine : log_dhl_licence_plate        #
# usage        :                                  #
# description  :  write the DHL LP number back to shipment_box table     #
# parameters   :   shipment_box_id,  lp_number                              #
# returns      :    licence plate identifier                             #

sub log_dhl_licence_plate :Export() {
    my ( $dbh, $shipment_box_id, $lp_number ) = @_;

    # DCS-1210: Have renamed field 'licence_plate_number' to 'tracking_number'
    my $qry = "update shipment_box set tracking_number = ? where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($lp_number, $shipment_box_id);

}

=head2 create_dhl_label( $dbh, $shipment_id, $box_id ) : Str

Attempts to find the label for a give shipment box id.
If the label does not already exist the create_dhl_xmlpi_label method is called
to generate the label via call to the DHL XMLPI service. Returns the label filename.

=cut
sub create_dhl_label :Export() {
    my ( $dbh, $shipment_id, $box_id ) = @_;

    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );

    # we want to make sure that, once we have created the labels, we
    # never override them: if the boxes for a multi-box shipment
    # arrive at different labeling stations, we have a race between
    # the stations. We don't care if we call DHL multiple times, but
    # we do care if we mix up the labels between those multiple calls.
    #
    # SO:
    # - we look at the shipment record
    my $shipment_row = $schema->resultset('Public::Shipment')->find($shipment_id);
    # - if the label file already exists and we have a valid outward
    # airwaybill, just return the file name
    my $label_filename = get_label_filename("$box_id.lbl");
    return $label_filename if ( -e $label_filename && $shipment_row->outward_airway_bill =~ m/\d{10}/ );

    # - otherwise, fetch the label data, and *maybe* store it in the
    # $shipment_row, see process_dhl_label_data
    $label_filename = create_dhl_xmlpi_label( $dbh, $shipment_row, $box_id );

    return $label_filename;
}

=head2 create_dhl_xmlpi_label( $dbh, $shipment, $box_id ) : Str

Creates the DHL label(s) for the shipment box(es) and the archive label.

Firstly a request XML is created via the build_label_request_xml of
XTracker::DHL::XMLDocument. This XML is submitted to the Shipment Validate service
of the DHL XMLPI service and the subsequent XML response is parsed by the
parse_label_response_xml method of XTracker::DHL::XMLDocument.

The parsed DHL data is processed by the process_dhl_label_data method and the
label filename is returned.

=cut
sub create_dhl_xmlpi_label {
    my ( $dbh, $shipment, $box_id ) = @_;

    ### get xmlpi details from the config
    my $xmlpi_info = dhl_xmlpi();

    my $xml_request;
    my $xml_response;
    my $dhl_label_data;

    ### create XML request for labelling service
    my $labelling_request_xml = XTracker::DHL::XMLDocument::build_label_request_xml( {
        shipment        => $shipment,
    } );
    my $got_error = 0;

    ### send XML request
    try {
        my $xml_request = XTracker::DHL::XMLRequest->new(client_host => $xmlpi_info->{address}, request_xml => $labelling_request_xml);
        $xml_response = $xml_request->send_xml_request;
    } catch {
        my $error = $_;
        xt_warn("Failed to send XML request to DHL: $error");
        xt_logger->error( __PACKAGE__ .": send_xml_request failed - "
                . pp($error)
                ."\nREQUEST:\n$labelling_request_xml" );
        $got_error = 1;
    };
    return if $got_error;

    ### parse response
    my @error_messages;
    try {
        $dhl_label_data = XTracker::DHL::XMLDocument::parse_label_response_xml($xml_response);

        # See if DHL reported any errors in their response
        if (defined($dhl_label_data->{error})) {
            for my $code (keys %{$dhl_label_data->{error}} ) {
                my $message = $dhl_label_data->{error}->{$code};
                push(@error_messages, sprintf('Error in DHL label retrieval: %s (code %s).',
                    $message,
                    $code
                ));
            }
        }

    } catch {
        # An unexpected exception occured
        my $error = sprintf('Error in DHL label retrieval: %s ', $_);
        push(@error_messages, $error);
    };
    if(@error_messages > 0) {
        xt_logger->warn( __PACKAGE__ .": parse_label_response_xml failed - "
            . pp($_)
            . "\nREQUEST:\n$labelling_request_xml"
            . "\nRESPONSE:\n$xml_response"
        );
        for my $error (@error_messages) {
            xt_warn($error);
        }

        return;
    }

    # this call may or may not update the $shipment: due to race
    # conditions, the row may have been already updated by this same
    # code in a different process; this call will always return a
    # usable label filename, though
    return process_dhl_label_data($dbh, $dhl_label_data, $shipment, $box_id);
}

=head2 process_dhl_label_data

Method processes the parsed DHL label data.

If the shipment does not already have a outward_airway_bill, the
parsed DHL data is processed and label files for all shipment boxes
and the shipment archive label are stored on disk for later
printing.

The filename for the label related to the supplied shipment_box_id is
returned, whether the label was generated in this call or at some time
before.

Parameters:
db handle, shipment_id, shipment_box_id

Return value:
the generated label file name, or die

=cut
sub process_dhl_label_data :Export(){
    my ($dbh, $label_data, $shipment, $box_id) = @_;
    my $xmlpi_info = dhl_xmlpi();
    my $label_filename;
    #update outwardairwaybill
    my $outward_air_waybill = $label_data->{AirwayBillNumber};
    die "Error: The outward air waybill is not in the recognised format [$outward_air_waybill]."
        unless $outward_air_waybill =~ m/\d{10}/;

    # set the airway bill, but only if there's not one already
    $shipment->result_source->resultset->search({
        id => $shipment->id,
        outward_airway_bill => [undef,'none'],
    })->update({
        outward_airway_bill => $label_data->{AirwayBillNumber},
    });
    $shipment->discard_changes; # force re-fetching the record
    if (($shipment->outward_airway_bill//'') ne $label_data->{AirwayBillNumber}) {
        # uh oh, the ->update above didn't do anything, we must have a
        # airway bill already!
        $label_filename = get_label_filename("$box_id.lbl");
        if ( -e $label_filename && $shipment->outward_airway_bill =~ m/\d{10}/ ) {
            xt_logger->info(
                sprintf 'while labeling box %s for shipment %s, we found it already had outward_airway_bill %s, so new airway bill %s was ignored',
                $shipment->id,$box_id,
                $shipment->outward_airway_bill//'undef',$label_data->{AirwayBillNumber},
            );
            return $label_filename;
        }
        # if we reach here, something is wrong: the ->update failed,
        # but we don't have a airway bill. Log, then override whatever
        # is there
        xt_logger->warn(
            sprintf 'while labeling box %s for shipment %s, we found it had outward_airway_bill %s and the label file %s %S, so new airway bill %s was used instead',
            $shipment->id,$box_id,
            $shipment->outward_airway_bill//'undef',
            $label_filename,(-e $label_filename ? 'is there' : 'is not there'),
            $label_data->{AirwayBillNumber},
        );
        $shipment->update({
            outward_airway_bill => $label_data->{AirwayBillNumber},
        });
    }

    # split image into label(s) and archive document
    my @dhl_box_label_images = split /$xmlpi_info->{zpl2_page_demarcation}/, decode_base64($label_data->{OutputImage});

    # SHIP-676: we only request archive label is shipment is dutiable
    if ( $shipment->requires_archive_label ) {
        my $archive_image = pop @dhl_box_label_images;
        my $archive_file = create_box_label_file( $shipment->id . "_archive_file.lbl", $archive_image);
        xt_logger->info("DHL archive file has been produced: $archive_file");
    }

    # update licence plate (tracking number) per box -> boxes are in id asc order
    my @shipment_boxes = $shipment->shipment_boxes->search( undef, { order_by => { -asc => 'id'} } )->all;

    # loop through tracking numbers and get corresponding box id and DHL label
    foreach my $key ( keys %{ $label_data->{BoxTrackingNumbers} } ) {
        die "Error: Shipment $shipment->id has a shipment box (id = $box_id) without a DHL tracking number."
            unless $shipment_boxes[$key];
        my $shipment_box = $shipment_boxes[$key];
        my $shipment_box_id = $shipment_box->id;
        my $tracking_number = $label_data->{BoxTrackingNumbers}->{$key};
        xt_logger->info("DHL tracking number for box with id $shipment_box_id is $tracking_number");
        log_dhl_licence_plate($dbh, $shipment_box_id, $tracking_number);
        my $box_label_file = create_box_label_file("$shipment_box_id.lbl", $dhl_box_label_images[$key]);
        $label_filename = $box_label_file if $shipment_box_id eq $box_id ;
    }

    xt_logger->info("DHL label file has been produced: $label_filename");
    return $label_filename;
}

sub create_box_label_file :Export(){
    my ($output_file_basename, $label) = @_;
    my $file_name = get_label_filename($output_file_basename);
    open(my $fh, '>', $file_name)
        or die "Couldn't create Shipment Label file ($file_name): $!\n";
    print $fh $label;
    close $fh;
    return $file_name;
}

sub get_label_filename :Export(){
    my ($basename) = @_;
    my $label_file = XTracker::PrintFunctions::path_for_print_document(
        XTracker::PrintFunctions::document_details_from_name( $basename ),
    );
    return $label_file;
}

sub render_label_template {
    my ($label_template, $output_file_basename, $template_data) = @_;
    $template_data ||= {};

    my $label;
    my $l_template = XTracker::XTemplate->template();
    $l_template->process( $label_template, { template_type => 'none', %$template_data }, \$label );

    my $file_name = XTracker::PrintFunctions::path_for_print_document(
        XTracker::PrintFunctions::document_details_from_name( $output_file_basename ),
    );
    open(my $fh, ">", $file_name)
        or die "Couldn't create Shipment Label file ($file_name): $!\n";
    print $fh $label;
    close $fh;

    return $file_name;
}

sub maybe_create_saturday_delivery_label :Export() {
    my ($shipment, $box_id) = @_;
    $shipment->is_saturday_nominated_delivery_date or return;

    my $label_filename = render_label_template(
        "print/saturday_delivery_service_alert_label.tt",
        "${box_id}_saturday_delivery_service_alert.lbl",
    );
    return $label_filename;
}

1;

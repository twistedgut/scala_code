package XTracker::Order::Printing::UPSBoxLabel;

use strict;
use warnings;
use Perl6::Export::Attrs;

use XTracker::PrintFunctions            qw( log_shipment_document print_ups_label );
use XTracker::Database::Shipment        qw( get_shipment_info :carrier_automation get_shipment_documents );
use XTracker::Database                  qw( get_schema_using_dbh );

=head2 print_ups_box_labels

usage        : print_ups_box_labels(
                    $dbh,
                    $shipment_id,
                    $label_printer
                );

description  : This first sees if there are any outward or return box labels to print for a shipment
               and if there are prints them. It prints all Outward labels first then the Return labels.
               At the moment this is really only useful for UPS Carrier Automation as the label data
               is got from the shipment_box table which is where the UPS Carrier Automation requests
               will put that data when it receives it back from UPS.

parameters   : A Database Handle, A Shipment Id and A Label Printer.
returns      : Nothing.

=cut

sub print_ups_box_labels :Export(:DEFAULT) {

    my ( $dbh, $shipment_id, $label_printer )   = @_;

    die "No Database Handle Passed"     if ( !$dbh );
    die "No Shipment Id Passed"         if ( !$shipment_id );
    die "No Label Printer Passed"       if ( !$label_printer );

    if ( !get_shipment_info( $dbh, $shipment_id ) ) {
        die "No Shipment found for Shipment Id: ".$shipment_id;
    }

    my $ship_print_logs = get_shipment_documents( $dbh, $shipment_id );

    #get shipment_returnable_status of the shipment
    my $schema = get_schema_using_dbh( $dbh, 'xtracker_schema' );
    my $shipment_row = $schema->resultset('Public::Shipment')->find($shipment_id);

    # get the box label data from each shipment box row
    my $lab_data    = get_shipment_box_labels( $dbh, $shipment_id );
    if ( @{ $lab_data } ) {
        # if we have label data to print then print each label

        # print Outward First
        foreach my $label ( @{ $lab_data } ) {
            if ( $label->{outward_label} ) {
                if ( !print_ups_label( {
                                prefix      => 'outward',
                                unique_id   => $label->{box_id},
                                label_data  => $label->{outward_label},
                                printer     => $label_printer,
                            } ) ) {
                    die "Couldn't Print Outward Label for Unique Id: ".$label->{box_id};
                }
                my $filename    = 'outward-'.$label->{box_id}.'.lbl';
                # always log a new label being printed, rather than only log once
                #if ( !grep( $_->{document} eq "Outward Shipping Label" && $_->{file} eq $filename ,values %{ $ship_print_logs } ) ) {
                    log_shipment_document( $dbh, $shipment_id, 'Outward Shipping Label', $filename, $label_printer );
                #}
            }
        }

        # print Return Second
        foreach my $label ( @{ $lab_data } ) {
            if ( $label->{return_label} && $shipment_row->is_returnable ) {
                if ( !print_ups_label( {
                                prefix      => 'return',
                                unique_id   => $label->{box_id},
                                label_data  => $label->{return_label},
                                printer     => $label_printer,
                            } ) ) {
                    die "Couldn't Print Return Label for Unique Id: ".$label->{box_id};
                }
                my $filename    = 'return-'.$label->{box_id}.'.lbl';
                # always log a new label being printed, rather than only log once
                #if ( !grep( $_->{document} eq "Return Shipping Label" && $_->{file} eq $filename ,values %{ $ship_print_logs } ) ) {
                    log_shipment_document( $dbh, $shipment_id, 'Return Shipping Label', $filename, $label_printer );
                #}
            }
        }
    }

    return;
}

1;

package XT::DC::Messaging::Plugins::PRL::PrintLabelRequest;
use NAP::policy "tt", 'class';

use Data::Dumper; # for error log messages
use DateTime;
use XTracker::Logfile qw(xt_logger);
use XTracker::Order::Printing::AddressCard;
use XTracker::PrinterMatrix;
use XT::JQ::DC;
my $log = xt_logger(__PACKAGE__);

=head1 NAME

XT::DC::Messaging::Plugins::PRL::PrintLabelRequest - Handle print message from PRL

=head1 DESCRIPTION
Consumer of the print_label_request message sent by Dematic PRL to XT.
Print all the docs that are requested at this stage

=head1 METHODS

=head2 message_type

Returns the name of the message

=cut

sub message_type { 'print_label_request' }

=head2 handler

=head3 Description

Receives the class name, context, and pre-validated payload.

=cut

sub handler {
    my ( $self, $c, $payload ) = @_;
    $c->log->debug('Received ' . $self->message_type . ' with: ' . Dumper( $payload ) );
    my $allocations = $payload->{'allocations'};

    # The locations in the messages look like e.g.
    #   DA.RP01.GTP04.PL04
    # The bit we're interested in is which GTP station it belongs
    # to, and we have printers configured only for 01 to 04.
    my ($gtp_location) = ($payload->{'location'} =~ /\.(GTP0[1-4])\./);

    die "Failed to find valid printer location for GTP location ".$payload->{'location'}
        unless ($gtp_location);

    #get database schema
    my $schema   = $c->model('Schema');
    my $dbh      = $schema->storage->dbh;

    my @response;
    #loop though all the allocations and print out the paperwork
    foreach my $allocation (@$allocations){

        #get the shipment
        my $shipment = $schema->resultset('Public::Allocation')->find($allocation->{'allocation_id'})
                                                                ->shipment;
        # Get a list of documents to print
        my @docs_to_print = $shipment->list_picking_print_docs();

        next unless scalar @docs_to_print;

        my $documents_info = $shipment->picking_print_docs_info();
        my $content = {allocation_id => $allocation->{'allocation_id'}};
        my @printers;
        foreach my $document (@docs_to_print){
            my $document_name = $document;
            $document_name =~ s/\s//g;
            my $printer;

            if ($document eq 'Address Card') {
                # Print the premier address card from the shipment
                $printer = 'Picking Premier Address Card ' . $gtp_location;
                generate_address_card(
                     $dbh,
                     $shipment->id,
                     $printer,
                     1
                );
            }
            elsif ($document eq 'MrP Sticker') {
                # Lookup the printer name from the picking station ID
                $printer = 'Picking MRP Sticker ' . $gtp_location;

                my $printer_info = XTracker::PrinterMatrix->new->get_printer_by_name($printer);
                my $item_count = $shipment->shipment_items->count();

                # Between August 2013 and June 2014, printing this sticker was
                #   sent off as a separate job to avoid blocking the consumer
                #   when the Zebra printers broke.
                #   See DCA-2710 / DCEA-1554
                # UPDATE: Now the Zebra printers work via XT::LP so we print
                #   directly again. See WHM-587
                $shipment->print_sticker( $printer_info->{lp_name}, $item_count );
            }
            elsif ($document eq 'Gift Message') {
                my $config_section = $shipment->order->channel->business->config_section;
                $printer = "Picking $config_section Gift Message $gtp_location"; # example name: Picking MRP Gift Message GTP02
                $shipment->print_gift_messages($printer);
            }
            else {
                $c->log->error("Don't know how to print document of type $document");
                next;
            }

            push @printers, {printer=> $printer, description=> $documents_info->{$document_name}->{description}, item => $document , quantity => 1};
        }
        $content->{printers} = \@printers;

        push @response , $content;
    }

    $c->model('MessageQueue')->transform_and_send(
        'XT::DC::Messaging::Producer::PRL::PrintLabelResponse' => {
            message => \@response,
            location => $payload->{'location'},
        }
    );
}

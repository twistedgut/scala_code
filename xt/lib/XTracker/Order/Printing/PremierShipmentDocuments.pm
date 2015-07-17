package XTracker::Order::Printing::PremierShipmentDocuments;
use strict;
use warnings;
use Perl6::Export::Attrs;

use XTracker::Order::Printing::AddressCard;
use XTracker::Order::Printing::GiftMessage;

sub print_premier_shipment_documents :Export(:DEFAULT) {
    my ($schema,$shipment,$premier_printer,$card_printer) = @_;

    return unless $shipment->is_premier;
    return if $shipment->is_transfer_shipment;

    # returns proforma
    $shipment->generate_return_proforma({
        printer => $premier_printer,
        copies  => 1,
    });

    # sales invoice
    my $renumeration = $shipment->get_sales_invoice;

    if ( $renumeration ) {
        $renumeration->generate_invoice({
            printer => $premier_printer,
            copies  => 1,
        });
    }

    # address card - this can sometimes be printed at picking,
    # so only print here if it has not already been printed
    unless ($shipment->address_card_printed){
        if ( $card_printer ) {
            generate_address_card(
                $schema->storage->dbh,
                $shipment->id,
                $card_printer,
                1
            );
        }
    }

    if (!$shipment->can_automate_gift_message() && $shipment->has_gift_messages()) {
        $shipment->print_gift_message_warnings($premier_printer);
    }

    return;
}

1;

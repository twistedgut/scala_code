package XTracker::Schema::ResultSet::Public::ShipmentPrintLog;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Readonly;

use base 'DBIx::Class::ResultSet';

Readonly our $DHL_INPUT_FORM => 'DHL Input Form';

sub dhl_printed_docs {
    my $resultset = shift;
    my $shipment_id = shift;

    my $list = $resultset->search(
        {
            shipment_id => $shipment_id,
            document => $DHL_INPUT_FORM,
        },
        {
        },
    );

    return $list;
}

1;

#!perl

=pod

Cancel all the orders that look like they might be making pending picks in IWS

=cut

use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :shipment_status
    :shipment_item_status
    :order_status
);
use XTracker::Database qw(:common);
use XTracker::Role::WithAMQMessageFactory;

my $factory = XTracker::Role::WithAMQMessageFactory->msg_factory;

my ( $schema, $dbh ) = get_schema_and_ro_dbh('xtracker_schema');

my $shipments_to_pause = find_held_shipments();

my %seen;
foreach my $shipment (@$shipments_to_pause) {
    next unless ($shipment->link_orders__shipments->first);
    next if $seen{$shipment->id};
    $seen{$shipment->id}=1;
    warn "Sending shipment_wms_pause for shipment ".$shipment->id."\n";
    $factory->transform_and_send('XT::DC::Messaging::Producer::WMS::ShipmentWMSPause',$shipment);
}

sub find_held_shipments {
    my @shipments = $schema->resultset('Public::Shipment')->search({
        'shipment_items.shipment_item_status_id' => [$SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED],
        'me.shipment_status_id' => $SHIPMENT_STATUS__HOLD,
    },
    {
        join => 'shipment_items',
        order => 'me.id',
    })->all;
    warn "Shipment (items) to do: ".scalar @shipments."\n";
    return \@shipments;
}

#!/opt/xt/xt-perl/bin/perl -w
use NAP::policy "tt";
use XTracker::Config::Local;
use XTracker::Database qw/schema_handle/;
use XTracker::Role::WithAMQMessageFactory;

my $schema = schema_handle();

my $factory = XTracker::Role::WithAMQMessageFactory->msg_factory;

foreach my $shipment_id (@ARGV) {

    print "Processing shipment $shipment_id\n";

    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

    unless ($shipment) {
        print "Couldn't find shipment $shipment_id\n";
        next;
    };

    # note this will take all items for a shipment regardless
    my $ship_items = $shipment->shipment_items;
    # update status of items from 'New' to 'Selected'   
    while ( my $item = $ship_items->next ) {
        $item->set_selected('971');
    }

    $factory->transform_and_send(
        'XT::DC::Messaging::Producer::WMS::ShipmentRequest',
        $shipment
    );
    print "Reprocessed shipment $shipment_id\n";
}

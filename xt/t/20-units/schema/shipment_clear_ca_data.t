#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::Data;
use Test::XTracker::Carrier;

use XTracker::Constants::FromDB         qw( :shipping_charge_class );
use XTracker::Config::Local             qw( config_var );


my $schema = Test::XTracker::Data->get_schema;
isa_ok($schema, 'XTracker::Schema',"Schema Created");

my($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 1,
});
my ($order)=Test::XTracker::Data->create_db_order({
    pids => $pids,
    base => {
        shipping_charge_id => $SHIPPING_CHARGE_CLASS__SAME_DAY,
    },
});

like( $order->get_standard_class_shipment->charge_class,
    qr/(Same Day|Ground|Air)/, 'Shipping Charge Class ok' );

# test clearing the carrier automation data for a shipment
my $carrier_test    = Test::XTracker::Carrier->new;
my $dc_name = config_var(qw/DistributionCentre name/);
my $shipment = $dc_name ~~ [qw/DC1 DC3/] ? $carrier_test->dhl_shipment
             : $dc_name eq 'DC2'         ? $carrier_test->ups_shipment
             : die "Unkown DC $dc_name";
$shipment->update( {
                outward_airway_bill => 'OUTWARD_AWB',
                return_airway_bill  => 'RETURN_AWB',
            } );
$shipment->shipment_boxes->update( {
                                tracking_number         => 'TRAK_NUM',
                                outward_box_label_image => 'OUTWARD_LABEL_IMG',
                                return_box_label_image  => 'RETURN_LABEL_IMG',
                            } );
$shipment->discard_changes;

# check everything is present
is( $shipment->outward_airway_bill, 'OUTWARD_AWB', 'Shipment Outward AWB Present' );
is( $shipment->return_airway_bill, 'RETURN_AWB', 'Shipment Return AWB Present' );
my $boxes   = $shipment->shipment_boxes;
while ( my $box = $boxes->next ) {
    is( $box->tracking_number, 'TRAK_NUM', 'Box Tracking Number Present' );
    is( $box->outward_box_label_image, 'OUTWARD_LABEL_IMG', 'Box Outward Label Present' );
    is( $box->return_box_label_image, 'RETURN_LABEL_IMG', 'Box Return Label Present' );
}

# clear everything
$shipment->clear_carrier_automation_data;

# check everything is cleared
$shipment->discard_changes;
is( $shipment->outward_airway_bill, 'none', 'Shipment Outward AWB NOT Present' );
is( $shipment->return_airway_bill, 'none', 'Shipment Return AWB NOT Present' );
$boxes   = $shipment->shipment_boxes;
while ( my $box = $boxes->next ) {
    is( $box->tracking_number, undef, 'Box Tracking Number NOT Present' );
    is( $box->outward_box_label_image, undef, 'Box Outward Label NOT Present' );
    is( $box->return_box_label_image, undef, 'Box Return Label NOT Present' );
}

done_testing();

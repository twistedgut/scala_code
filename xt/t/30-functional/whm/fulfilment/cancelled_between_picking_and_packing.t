#!/usr/bin/env perl

=head1 NAME

cancelled_between_picking_and_packing.t - Cancel an item between picking and packing

=head1 DESCRIPTION

This test only runs in DC1.

These tests exist to ensure that we handle Invar's behaviour around
cancellations during picking.

Create three single-item shipments with a status of I<Selected>.

Send a shipment_ready message for each shipment, placing all shipments into the
same container, and check the status is updated to I<Picked>.

Cancel the second shipment and check its status is I<Cancel Pending>.

Pack the container, mark it as empty, and check that the cancelled item's
status is I<Cancelled>.

Check that I<log_stock> has been updated.

#TAGS fulfilment packing cancelitem iws orderview whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XT::Flow;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Database qw(:common);
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Config::Local 'config_var';
use Test::XT::Data::Container;
use Test::Differences;
use Test::XTracker::RunCondition dc => 'DC1';

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Data::Location'
    ],
);
$framework->login_with_permissions({
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                    'Fulfilment/Packing',
                    'Fulfilment/Packing Exception',
                    'Fulfilment/Selection'
                ]
            }
});

my $invar_location = $framework->data__location__get_invar_location; # Just to make sure
my $schema = Test::XTracker::Data->get_schema;

my $amq = Test::XTracker::MessageQueue->new();

# Grab 3 products in to P1 .. P3
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 3 });
my %products = map {; "P$_" => shift( @$pids ) } 1..3;
my @actual_pids = map { $products{$_}->{'pid'} } keys %products;

my $shipment = $framework->flow_db__fulfilment__create_order_selected(
        channel  => $channel,
        products => [ @products{qw/P1/} ],
    );


my $shipment2 = $framework->flow_db__fulfilment__create_order_selected(
        channel  => $channel,
        products => [ @products{qw/P2/} ],
    );

my $shipment3 = $framework->flow_db__fulfilment__create_order_selected(
        channel  => $channel,
        products => [ @products{qw/P3/} ],
    );
$framework
->flow_mech__customercare__orderview( $shipment->{'order_object'}->id )
->flow_mech__customercare__orderview_status_check(
        $shipment->{'order_object'}->id,
        [
            [ sku('P1') => 'Selected' ],
        ], "Items match before first shipment_ready" );

$framework
->flow_mech__customercare__orderview( $shipment2->{'order_object'}->id )
->flow_mech__customercare__orderview_status_check(
        $shipment2->{'order_object'}->id,
        [
            [ sku('P2') => 'Selected' ],
        ], "Items match before second shipment_ready" );

$framework
->flow_mech__customercare__orderview( $shipment3->{'order_object'}->id )
->flow_mech__customercare__orderview_status_check(
        $shipment3->{'order_object'}->id,
        [
            [ sku('P3') => 'Selected' ],
        ], "Items match before third shipment_ready" );


#Send a ShipmentReady
my @container_id = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );
my $container_id = shift @container_id;

my @containers = (
    {
        container_id => $container_id,
        items => [
            map {{ sku => $_->{'sku'}, quantity => 1 }} @products{ 'P1' .. 'P3' }
        ],
    },
);

{
my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');
$amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::ShipmentReady', [$shipment->{'shipment_id'}, \@containers] );
$wms_to_xt->wait_for_new_files();
$amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::ShipmentReady', [$shipment2->{'shipment_id'}, \@containers] );
$wms_to_xt->wait_for_new_files();
$amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::ShipmentReady', [$shipment3->{'shipment_id'}, \@containers] );
$wms_to_xt->wait_for_new_files();
}

my $count = $schema->resultset('Public::LogStock')->search({variant_id => $products{'P3'}->{variant_id}})->count;

# Check we handled that nicely - P1, 2, 3 should be picked
$framework->flow_mech__customercare__orderview_status_check(
    $shipment->{'order_object'}->id,
    [
        [ sku('P1') => 'Picked' ],
    ], "Items match after first shipment_ready" );
$framework->flow_mech__customercare__orderview_status_check(
    $shipment2->{'order_object'}->id,
    [
        [ sku('P2') => 'Picked' ],
    ], "Items match after second  shipment_ready" );

$framework->flow_mech__customercare__orderview_status_check(
    $shipment3->{'order_object'}->id,
    [
        [ sku('P3') => 'Picked' ],
    ], "Items match after third  shipment_ready" );

# Cancel second shipment
$framework
->flow_mech__customercare__orderview( $shipment2->{'order_object'}->id )
->flow_mech__customercare__cancel_order($shipment2->{'order_object'}->id)
->flow_mech__customercare__cancel_order_submit
->flow_mech__customercare__cancel_order_email_submit
->flow_mech__customercare__orderview_status_check(
        $shipment2->{'order_object'}->id,
        [
            [ sku('P2') => 'Cancel Pending' ],
        ], "Status match after second shipment cancel" );

# Pack the tote
$framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $container_id)
        ->flow_mech__fulfilment__packing_submit( sku('P1') )
        ->flow_mech__fulfilment__packing_checkshipment_submit
        ->flow_mech__fulfilment__packing_packshipment_submit_sku( sku('P1') )
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            channel_id => $channel->id
        )
        ->flow_mech__fulfilment__packing_packshipment_submit_waybill(
            "0123456789"
        )
        ->flow_mech__fulfilment__packing_packshipment_complete();

$framework->mech->get("/Fulfilment/Packing/CheckShipment?auto=completed&shipment_id=$container_id");
$framework
        ->flow_mech__fulfilment__packing_checkshipment_submit
        ->flow_mech__fulfilment__packing_packshipment_submit_sku( sku('P3') )
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            channel_id => $channel->id
        )
        ->flow_mech__fulfilment__packing_packshipment_submit_waybill(
            "0124553459"
        )
        ->flow_mech__fulfilment__packing_packshipment_complete();
$framework->mech->get("/Fulfilment/Packing/CheckShipment?auto=completed&shipment_id=$container_id");
$framework->assert_location(qr!^/Fulfilment/Packing/EmptyTote!);
$framework
        ->flow_mech__fulfilment__packing_emptytote_submit('yes');

#Check status
$framework
->flow_mech__customercare__orderview( $shipment2->{'order_object'}->id )
->flow_mech__customercare__orderview_status_check(
        $shipment2->{'order_object'}->id,
        [
            [ sku('P2') => 'Cancelled' ],
        ], "Status changed after competing packing" );


my $stock_after = $schema->resultset('Public::LogStock')->search({variant_id => $products{'P3'}->{variant_id}})->count;

cmp_ok($stock_after , ">", $count, "Transactional log updated");

done_testing();

sub sku {
    my $pid = shift();
    return $products{$pid}->{'sku'};
}


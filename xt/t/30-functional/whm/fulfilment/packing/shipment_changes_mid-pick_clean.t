#!/usr/bin/env perl

=head1 NAME

shipment_changes_mid-pick_clean.t - Shipment changes mid-pick

=head1 DESCRIPTION

Handle IWS behaviour around cancellations during picking.

#TAGS fulfilment iws orderview picking whm

=head1 SEE ALSO

shipment_changes_mid-pick_dirty.t

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level );
use Test::XT::Data::Container;
use Test::Differences;

use Test::XTracker::RunCondition iws_phase => 'iws';

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    dept => 'Customer Care',
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search'
    ]}
});
my $invar_location = $framework->data__location__get_invar_location; # Just to make sure

# grab_multi_variant_product does not create products if they're not there...
# grab_products does. I'm too lazy to change the rest of the code
my ($channel)=Test::XTracker::Data->grab_products({
    how_many => 5,
    how_many_variants => 2,
    ensure_stock_all_variants => 1,
});
# Grab 3 products in to P1 .. P3
my (undef,$pids) = Test::XTracker::Data->grab_products({
    channel => $channel,
    how_many => 3,
});
my %products = map {; "P$_" => shift( @$pids ) } 1..3;
my @actual_pids = map { $products{$_}->{'pid'} } keys %products;

# Make 4,6 and 5,7 variant pairs
for my $i ( [4,6], [5,7] ) {
    my (undef, $variants) =
        Test::XTracker::Data->grab_multi_variant_product({
            channel => $channel,
            ensure_stock => 1,
            'not' => \@actual_pids
        });
    ( $products{'P' . $i->[0]}, $products{'P' . $i->[1]} ) = @$variants;
    push( @actual_pids, $variants->[0]->{'pid'} );
}

# Create an order of products 1-5. We'll use 6 and 7 as our replacement items
my $shipment = $framework->flow_db__fulfilment__create_order_selected(
    channel  => $channel,
    products => [ @products{qw/P1 P2 P3 P4 P5/} ],
)->{shipment_object};
my $order = $shipment->order;

$framework
    ->flow_mech__customercare__orderview_status_check(
        $order->id,
        [
            [ sku('P1') => 'Selected' ],
            [ sku('P2') => 'Selected' ],
            [ sku('P3') => 'Selected' ],
            [ sku('P4') => 'Selected' ],
            [ sku('P5') => 'Selected' ],
        ], "all items should be selected" );
# Size change
$framework
    ->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__size_change()
    ->flow_mech__customercare__size_change_submit( [ sku('P4') => sku('P6') ] )
    ->flow_mech__customercare__size_change_email_submit
    ->flow_mech__customercare__orderview_status_check(
        $order->id,
        [
            [ sku('P1') => 'Selected' ],
            [ sku('P2') => 'Selected' ],
            [ sku('P3') => 'Selected' ],
            [ sku('P4') => 'Cancelled' ],
            [ sku('P5') => 'Selected' ],
            [ sku('P6') => 'Selected' ],
        ], "shipment items pre-picking commenced after size change as expected" );
# Cancel an item
$framework
    ->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__cancel_shipment_item()
    ->flow_mech__customercare__cancel_item_submit(
        sku('P1')
    )->flow_mech__customercare__cancel_item_email_submit
    ->flow_mech__customercare__orderview_status_check(
        $order->id,
        [
            [ sku('P1') => 'Cancelled' ],
            [ sku('P2') => 'Selected' ],
            [ sku('P3') => 'Selected' ],
            [ sku('P4') => 'Cancelled' ],
            [ sku('P5') => 'Selected' ],
            [ sku('P6') => 'Selected' ],
        ], "shipment items pre-picking commenced after cancellation as expected" );

# Send a ShippingCommenced
$framework->flow_wms__send_picking_commenced( $shipment );

# Cancel two items but only include just one of them in the shipment ready
# message
$framework
    ->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__cancel_shipment_item()
    ->flow_mech__customercare__cancel_item_submit(
        sku('P2')
    )->flow_mech__customercare__cancel_item_email_submit
    ->flow_mech__customercare__cancel_shipment_item()
    ->flow_mech__customercare__cancel_item_submit(
        sku('P3')
    )->flow_mech__customercare__cancel_item_email_submit
    ->flow_mech__customercare__orderview_status_check(
        $order->id,
        [
            [ sku('P1') => 'Cancel Pending' ],
            [ sku('P2') => 'Cancel Pending' ],
            [ sku('P3') => 'Cancel Pending' ],
            [ sku('P4') => 'Cancel Pending' ],
            [ sku('P5') => 'Selected' ],
            [ sku('P6') => 'Selected' ],
        ], "shipment items pre-shipment ready as expected" );

my @container_ids = Test::XT::Data::Container->get_unique_ids( { how_many => 4 } );
# Send a ShipmentReady - include just one of the 'Cancel Pending' items
$framework->flow_wms__send_shipment_ready(
    shipment_id => $shipment->id,
    container => {
        (shift @container_ids) => [ map { $_->{sku} } @products{ map { "P$_" } (2,5) } ],
        (shift @container_ids) => [ $products{P6}{sku} ],
    },
);

# Check we handled that nicely - P5,6 should be Picked, P2 should be Cancel
# Pending (will be 'Cancelled' once its gone through Packing Exception) P1,3,4
# should be Cancelled
$framework->flow_mech__customercare__orderview_status_check(
    $order->id,
    [
        [ sku('P1') => 'Cancelled' ],
        [ sku('P2') => 'Cancel Pending' ],
        [ sku('P3') => 'Cancelled' ],
        [ sku('P4') => 'Cancelled' ],
        [ sku('P5') => 'Picked' ],
        [ sku('P6') => 'Picked' ],
    ], "shipment items after shipment ready as expected" );


# Size change
$framework
    ->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__size_change()
    ->flow_mech__customercare__size_change_submit( [ sku('P5') => sku('P7') ] )
    ->flow_mech__customercare__size_change_email_submit;
# Cancel an item
$framework
    ->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__cancel_shipment_item()
    ->flow_mech__customercare__cancel_item_submit(
        sku('P6')
    )->flow_mech__customercare__cancel_item_email_submit
    ->flow_mech__customercare__orderview_status_check(
        $order->id,
        [
            [ sku('P1') => 'Cancelled' ],
            [ sku('P2') => 'Cancel Pending' ],
            [ sku('P3') => 'Cancelled' ],
            [ sku('P4') => 'Cancelled' ],
            [ sku('P5') => 'Cancel Pending' ],
            [ sku('P6') => 'Cancel Pending' ],
            [ sku('P7') => 'Selected' ],
        ], "shipment items between shipment ready messages as expected" );

# Send a ShipmentReady
$framework->flow_wms__send_shipment_ready(
    shipment_id => $shipment->id,
    container => {
        (shift @container_ids) => [ map { $_->{sku} } @products{ map { "P$_" } (2,5,7) } ],
        (shift @container_ids) => [ $products{P6}{sku} ],
    },
);

# Check we handled that nicely
$framework->flow_mech__customercare__orderview_status_check(
    $order->id,
    [
        [ sku('P1') => 'Cancelled' ],
        [ sku('P2') => 'Cancel Pending' ],
        [ sku('P3') => 'Cancelled' ],
        [ sku('P4') => 'Cancelled' ],
        [ sku('P5') => 'Cancel Pending' ],
        [ sku('P6') => 'Cancel Pending' ],
        [ sku('P7') => 'Picked' ],
    ], "shipment items after both shipment ready messages as expected" );


done_testing();

sub sku {
    my $pid = shift();
    return $products{$pid}->{'sku'};
}

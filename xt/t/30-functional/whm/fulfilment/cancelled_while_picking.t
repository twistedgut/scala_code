#!/usr/bin/env perl

=head1 NAME

cancelled_while_picking.t - Test cancelling a shipment item while picking

=head1 DESCRIPTION

This test runs in IWS phase only.

These tests exist to ensure that we handle Invar's behaviour around
cancellations during picking.

Create a bunch of products such that P4 and P6, P5 and P7, and P3 and P8 are
variants of the same products.

Create a shipment with a status of I<Selected> containing 5 items. Cancel the
first one (P1) and do a size change for the fourth one (P4) - check that they
are both I<Cancelled> and all other items are I<Selected>, including the new
item (P6) following the size change.

Send a I<picking commenced>, followed by a I<shipment_ready>, the first 5 items
(P1-5) in one container, and the size-changed item (P6) in another one.

Check that two items (P1,4) are I<Cancel Pending>, and the others are all
I<Picked>.

Perform another size change (P5 to P7) and cancel an item (P2). Check that four
items (P1,2,4,5) are I<Cancel Pending>, two items (P3,6) are I<Picked>, and one
(P7) is I<Selected>.

Send another I<shipment_ready> with P7 in its own container. Check that four
items (P1,2,4,5) are I<Cancel Pending> and three (P3,6,7) are I<Picked>.

Do another size change (P3 to P8), and check we now have five items (P1-5) in
I<Cancel Pending>, two items (P6-7) in I<Picked> and one item (P8) in
I<Selected>. Send another I<shipment_ready> for P8 and check that it's now
I<Picked>.

#TAGS iws cancelitem changeitemsize fulfilment picking orderview whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level );
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::Data;
use Test::XT::Data::Container;
use Test::Differences;
use Test::XTracker::RunCondition iws_phase => [1,2];

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::WMS',
    ],
);
Test::XTracker::Data->set_department('it.god', 'Customer Care');
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search'
    ]}
});
my $invar_location = $framework->data__location__get_invar_location; # Just to make sure

# Grab 2 products in to P1 .. P2
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 2, force_create => 1 });
my %products = map {; "P$_" => shift( @$pids ) } 1..2;
my @actual_pids = map { $products{$_}->{'pid'} } keys %products;

# Make 4,6 and 5,7 variant pairs
for my $i ( [4,6], [5,7], [3,8] ) {
    my ($new_channel, $variants) =
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

# Size change
$framework
    ->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__size_change()
    ->flow_mech__customercare__size_change_submit( [ sku('P4') => sku('P6') ] )
    ->flow_mech__customercare__size_change_email_submit
# Cancel an item
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
        ], "Items match before first shipment_ready" );

$framework->flow_wms__send_picking_commenced( $shipment );
# Send a ShipmentReady
my @container_ids = Test::XT::Data::Container->get_unique_ids( { how_many => 5 } );
my $containers = {
    shift( @container_ids ) => [
        map { $_->{sku} } @products{ 'P1' .. 'P5' }
    ],
    shift( @container_ids ) => [ $products{P6}{sku} ],
};
$framework->flow_wms__send_shipment_ready(
    shipment_id => $shipment->id,
    container => $containers,
);

# Check we handled that nicely - P2,3,5,6 should be picked, P1,4 should be Cancel Pending
$framework->flow_mech__customercare__orderview_status_check(
    $order->id,
    [
        [ sku('P1') => 'Cancel Pending' ],
        [ sku('P2') => 'Picked' ],
        [ sku('P3') => 'Picked' ],
        [ sku('P4') => 'Cancel Pending' ],
        [ sku('P5') => 'Picked' ],
        [ sku('P6') => 'Picked' ],
    ], "Items match after first shipment_ready" );


# Size change
$framework
    ->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__size_change()
    ->flow_mech__customercare__size_change_submit( [ sku('P5') => sku('P7') ] )
    ->flow_mech__customercare__size_change_email_submit
# Cancel an item
    ->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__cancel_shipment_item()
    ->flow_mech__customercare__cancel_item_submit(
        sku('P2')
    )->flow_mech__customercare__cancel_item_email_submit
    ->flow_mech__customercare__orderview_status_check(
        $order->id,
        [
            [ sku('P1') => 'Cancel Pending' ],
            [ sku('P2') => 'Cancel Pending' ],
            [ sku('P3') => 'Picked' ],
            [ sku('P4') => 'Cancel Pending' ],
            [ sku('P5') => 'Cancel Pending' ],
            [ sku('P6') => 'Picked' ],
            [ sku('P7') => 'Selected' ],
        ], "Items match before second shipment_ready" );

# Send a ShipmentReady
$containers->{shift( @container_ids )} = [ $products{P7}{sku} ];
$framework->flow_wms__send_shipment_ready(
    shipment_id => $shipment->id,
    container => $containers,
);

# Check we handled that nicely
$framework->flow_mech__customercare__orderview_status_check(
    $order->id,
    [
        [ sku('P1') => 'Cancel Pending' ],
        [ sku('P2') => 'Cancel Pending' ],
        [ sku('P3') => 'Picked' ],
        [ sku('P4') => 'Cancel Pending' ],
        [ sku('P5') => 'Cancel Pending' ],
        [ sku('P6') => 'Picked' ],
        [ sku('P7') => 'Picked' ],
    ], "Items match after second shipment_ready" );



#change size back
$framework
    ->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__size_change()
    ->flow_mech__customercare__size_change_submit( [ sku('P3') => sku('P8') ] )
    ->flow_mech__customercare__size_change_email_submit
    ->flow_mech__customercare__orderview_status_check(
        $order->id,
        [
            [ sku('P1') => 'Cancel Pending' ],
            [ sku('P2') => 'Cancel Pending' ],
            [ sku('P3') => 'Cancel Pending' ],
            [ sku('P4') => 'Cancel Pending' ],
            [ sku('P5') => 'Cancel Pending' ],
            [ sku('P6') => 'Picked' ],
            [ sku('P7') => 'Picked' ],
            [ sku('P8') => 'Selected' ],
        ], "Items match before third shipment_ready" );

# Send a ShipmentReady
$framework->flow_wms__send_shipment_ready(
    shipment_id => $shipment->id,
    container => { shift(@container_ids) => [$products{P8}{sku}] },
);

# Check we handled that nicely
$framework->flow_mech__customercare__orderview_status_check(
    $order->id,
    [
        [ sku('P1') => 'Cancel Pending' ],
        [ sku('P2') => 'Cancel Pending' ],
        [ sku('P3') => 'Cancel Pending' ],
        [ sku('P4') => 'Cancel Pending' ],
        [ sku('P5') => 'Cancel Pending' ],
        [ sku('P6') => 'Picked' ],
        [ sku('P7') => 'Picked' ],
        [ sku('P8') => 'Picked' ],
    ], "Items match after second shipment_ready" );




done_testing();

sub sku {
    my $pid = shift();
    return $products{$pid}->{'sku'};
}

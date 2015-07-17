#!/usr/bin/env perl

=head1 NAME

multi_shipment_tote_items_change.t - Test packing a multi-shipment

=head1 DESCRIPTION

PE = Packing Exception

Scenario as follows:
    * Shipment containing P1 picked into tote T1
    * P1 exchanged for P2
    * P2 picked into T2, shipment ready message sent - contains details about both items
    * Tote T1 arrives at packing
    * Packer confirms tote is empty, cancelled item scanned into T3 to send to PE
    * Packer scans T2 and packs replacement item
    * Packer asked to confirm that tote T2 is empty
    * Verify T3 is not be mentioned at this point
    * Ensure T3 can still be dealt with at PE desk

    Check the contents of the "is tote empty" page.
    Confirm that the pick tote (not the PE tote) is empty.
    Verify PE tote is still superfluous status.
    Verify one item still in PE tote.

#TAGS fulfilment packing packingexception iws whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::More::Prefix qw/test_prefix/;
use Test::Differences;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB qw(:authorisation_level);
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;

use Test::XTracker::RunCondition iws_phase => 'iws';

test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Data::Location',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

test_prefix("Setup: data");
# create and pick the order
my ($channel, undef) = Test::XTracker::Data->grab_products({
    how_many => 1,
});
my (undef, $pids) = Test::XTracker::Data->grab_multi_variant_product({
    ensure_stock => 1
});
my $shipment = $framework->flow_db__fulfilment__create_order_selected( channel  => $channel, products => [ $pids->[0] ], )->{shipment_object};
my $shipment_id = $shipment->id;
my $order = $shipment->order;
note "shipment $shipment_id created";


note "exchange item in the order";
$framework
    ->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__size_change()
    ->flow_mech__customercare__size_change_submit( [ $pids->[0]->{sku} => $pids->[1]->{sku} ] )
    ->flow_mech__customercare__size_change_email_submit
# is the shipment in a sensible state
    ->flow_mech__customercare__orderview_status_check(
        $order->id,
        [
            [ $pids->[0]->{sku} => 'Cancelled' ],
            [ $pids->[1]->{sku} => 'Selected' ],
        ], "Items match before first shipment_ready" );
# clear iws directory of shipment_request message
$xt_to_wms->new_files;


$framework->flow_wms__send_picking_commenced( $shipment );
my ($pick_tote1_id, $pick_tote2_id, $PE_tote_id) = Test::XT::Data::Container->get_unique_ids({ how_many => 3 });
note "Tote 1: $pick_tote1_id; Tote 2: $pick_tote2_id; Tote 3: $PE_tote_id";
# send/receive second shipment ready - contains information about both items
$framework->flow_wms__send_shipment_ready(
    shipment_id => $shipment_id,
    container => {
        $pick_tote1_id => [ $pids->[0]->{sku} ],
        $pick_tote2_id => [ $pids->[1]->{sku} ],
    },
);




test_prefix("First tote arrives at packer. Put cancelled item in tote to PE");
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $pick_tote1_id )
    ->flow_mech__fulfilment__packing_emptytote_submit('no');
like($framework->mech->app_info_message,
     qr{Please scan unexpected item},
     'packer asked to send shipment to exception desk');
$framework
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($pids->[0]->{sku})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($PE_tote_id)
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete
    ->flow_mech__fulfilment__packing_emptytote_submit('yes');
# check we sent item_moved message
$xt_to_wms->expect_messages({
    messages => [
        {
            '@type'   => 'item_moved',
            'details' => { 'shipment_id' => "s-$shipment_id",
                           'from'  => {container_id => $pick_tote1_id},
                           'to'    => {container_id => $PE_tote_id},
                           'items' => [{sku => $pids->[0]->{sku},
                                        quantity => 1,}],
                         },
        },
    ]
});


test_prefix("Second tote arrives at packer. Pack item.");
$framework
    ->flow_mech__fulfilment__packing_submit( $pick_tote2_id );
is($framework->mech->app_info_message, undef,
     "Should have no info message here as shipment is in single container");
$framework
    ->flow_mech__fulfilment__packing_checkshipment_submit()
    ->flow_mech__fulfilment__packing_packshipment_submit_sku( $pids->[1]->{sku} )
    ->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $channel->id )
    ->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
    ->flow_mech__fulfilment__packing_packshipment_complete
    ->flow_mech__fulfilment__packing_packshipment_follow_redirect;
$xt_to_wms->expect_messages({
    messages => [
        {
            'type'   => 'shipment_received',
            'details' => { shipment_id => "s-$shipment_id" }
        },
        {
            'type'   => 'shipment_packed',
            'details' => { shipment_id => "s-$shipment_id" }
        },
    ]
});



# This is what we've really been building up to - check the contents of the "is tote empty" page
test_prefix("Interesting bit of the test...");
is_deeply($framework->mech->as_data()->{totes}, [$pick_tote2_id], "only confirm that the pick tote (not the PE tote) is empty");
$framework->flow_mech__fulfilment__packing_emptytote_submit('yes');

# check PE tote status and contents
my $PE_tote = $framework->schema->resultset('Public::Container')->find($PE_tote_id);
ok($PE_tote->is_superfluous, "PE tote is still superfluous status");
is($PE_tote->shipment_items->count, 1 ,"One item still in PE tote");

done_testing();


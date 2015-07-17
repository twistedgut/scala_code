#!/usr/bin/env perl

=head1 NAME

incomplete_pick_phase0.t - Test the incomplete_pick message (IWS off)

=head1 DESCRIPTION

Setup as follows:

    - create an order (selected) with multiple items/vouchers
    - send incomplete message and test consequences

    - repeat, incomplete_picking regular products, vouchers and virtual vouchers
    - create a sample shipment and try 'incomplete_pick'ing that

#TAGS fulfilment packing packingexception iws phase0 checkruncondition voucher whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

#
#use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::XT::Flow;

use XTracker::Config::Local qw( config_var config_section_slurp );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_status);
use XTracker::Database qw(:common);
use Test::XTracker::Artifacts::RAVNI;
use Carp::Always;

use Test::XTracker::RunCondition dc => 'DC1', iws_phase => '0', export => qw( $iws_rollout_phase );

# Start-up gubbins here. Test plan follows later in the code...
test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Data::Location',
    ],
);
my $schema = $framework->schema;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Stock Control/Inventory',
        'Stock Control/Sample',
        'Fulfilment/Selection',
        'Fulfilment/Packing'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);
my $amq = Test::XTracker::MessageQueue->new();
my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');


# get some products
test_prefix("Setup: grab products");
my ($channel,$pids) = Test::XTracker::Data->grab_products({
                                how_many => 1, channel => 'nap',
                                phys_vouchers => {
                                    how_many => 1,
                                },
                                virt_vouchers => {
                                    how_many => 1,
                                },
 });
note "working with skus : " . join ', ', map {$_->{sku}} @$pids;

my @tests = map {type => 'customer', pid => $_}, @$pids;
push @tests, {type => 'sample', pid => $pids->[0]};

# place an order and incomplete_pick pid in turn
foreach my $test (@tests){
    test_prefix("Setup: place $test->{type} order");
    my ($shipment_id, $shipment);
    if ($test->{type} eq 'sample'){
        # create a sample shipment, selected

        Test::XTracker::Data->set_department('it.god', 'Sample');
        $framework->mech->test_create_sample_request( [$test->{pid}] );
        note "sample request created";

        Test::XTracker::Data->set_department('it.god', 'Stock Control');
        $framework->mech->test_approve_sample_request( [$test->{pid}] );
        note "sample request approved";

        note "Select transfer shipment";
        $shipment_id = $test->{pid}->{shipment_id};
        $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

        $framework->flow_mech__fulfilment__selection_transfer
            ->flow_mech__fulfilment__selection_submit($shipment_id);

        # confirm it created it as we expect
        ok($shipment->is_transfer_shipment, "shipment is a sample transfer");
        ok(!$shipment->is_cancelled, "Shipment not cancelled");
        is($shipment->canceled_items->count, 0, "shipment has no cancelled items");
        ok(!$shipment->stock_transfer->is_cancelled, 'stock transfer is not cancelled');
    } else {
        # create a regular shipment, selected
        my $order_data = $framework->flow_db__fulfilment__create_order_selected( channel  => $channel, products => $pids, );
        $shipment_id = $order_data->{shipment_id};
        $shipment = $order_data->{'shipment_object'};
    }
    note "shipment $shipment_id created";

    my $current_stock = $test->{pid}->{variant}->current_stock_on_channel($channel->id);

    # send incomplete_pick
    test_prefix("Test incomplete_picking sku $test->{pid}->{sku}");
    $xt_to_wms->new_files; #reset read dir
    $amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::PickingCommenced', $shipment );
    $wms_to_xt->wait_for_new_files(files => 1);
    $amq->transform_and_send( 'XT::DC::Messaging::Producer::WMS::IncompletePick', {
        'shipment_id' => "$shipment_id",
        'items' => [
            {
                'sku' => $test->{pid}->{sku},
                'quantity' => 1,
            }
        ],
    });
    # wait for receipt
    $wms_to_xt->wait_for_new_files(files => 1);

    $shipment->discard_changes;
    if ($test->{type} eq 'sample'){
        ok($shipment->is_cancelled, "Shipment is now cancelled");
        is($shipment->canceled_items->count, 1, "shipment has cancelled item");
        # sample stock transfer should be cancelled
        ok($shipment->stock_transfer->is_cancelled, 'stock transfer is now cancelled');
    } elsif ($test->{type} eq 'customer_cancelled_item') {
        $framework->errors_are_fatal(0);
        $framework->flow_mech__fulfilment__packing()
            ->flow_mech__fulfilment__packing_submit($shipment_id);
        $framework->errors_are_fatal(1);
        like ($framework->mech->app_error_message,
            qr{This shipment should not be at packing, as the shipment items are not in containers},
            "Correct error message shown when shipment id entered at packing"
        );

        # should have sent a 'pause' message (but no others)
        $xt_to_wms->expect_messages({
            messages => [{
                '@type'   => 'shipment_cancel',
                'details' => { 'shipment_id' => "s-$shipment_id"},
            }]
        });

    } else {
        # now shipment should be on hold
        is ($shipment->shipment_status_id, $SHIPMENT_STATUS__HOLD, 'shipment on hold');
    }

    # inventory should not change
    my $new_stock = $test->{pid}->{variant}->current_stock_on_channel($channel->id);
    is($current_stock, $new_stock, "stock is now $new_stock")
}

done_testing;


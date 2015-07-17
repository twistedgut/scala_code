#!/usr/bin/env perl

=head1 NAME

incomplete_pick.t - Test the incomplete_pick message

=head1 DESCRIPTION

Setup as follows:

    - create a selected order with multiple items/vouchers
    - send incomplete message and test consequences

    - repeat, incomplete_picking regular products, vouchers and virtual vouchers
    - create a sample shipment and try 'incomplete_pick'ing that

#TAGS fulfilment picking iws checkruncondition whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw(:authorisation_level);
use Test::XTracker::Artifacts::RAVNI;
use Carp::Always;

use Test::XTracker::RunCondition dc => 'DC1', iws_phase => 'iws';

# Start-up gubbins
test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Stock Control/Inventory',
        'Stock Control/Sample',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);
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
push @tests, {type => 'customer_cancelled_item', pid => $pids->[0]};
push @tests, {type => 'sample', pid => $pids->[0]};

# place an order and incomplete_pick pid in turn
foreach my $test (@tests){
    test_prefix("Setup: place $test->{type} order");
    my ($shipment_id, $shipment, $order_id);
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
        $shipment = $framework->schema->resultset('Public::Shipment')->find($shipment_id);

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
        $order_id      = $order_data->{order_object}->id;
        $shipment_id   = $order_data->{shipment_id};
        $shipment      = $order_data->{'shipment_object'};
    }
    note "shipment $shipment_id created";

    if ($test->{type} eq 'customer_cancelled_item'){
        $framework->flow_mech__customercare__orderview( $order_id )
            ->flow_mech__customercare__cancel_shipment_item()
            ->flow_mech__customercare__cancel_item_submit( [ $test->{pid}->{sku} ] )
            ->flow_mech__customercare__cancel_item_email_submit;
    }

    my $current_stock = $test->{pid}->{variant}->current_stock_on_channel($channel->id);
    # send incomplete_pick
    test_prefix("Test incomplete_picking sku $test->{pid}->{sku}");
    $xt_to_wms->new_files; #reset read dir
    $framework->flow_wms__send_picking_commenced( $shipment );
    $framework->flow_wms__send_incomplete_pick(
        shipment_id => $shipment_id,
        operator_id => $APPLICATION_OPERATOR_ID,
        items => [ $test->{pid}{sku} ],
    );

    my $new_stock = $test->{pid}->{variant}->current_stock_on_channel($channel->id);
    if ($test->{type} eq 'customer_cancelled_item') {
        # should have sent an 'pause' message
        $xt_to_wms->expect_messages({
            messages => [{
                '@type'   => 'shipment_wms_pause',
                'details' => { 'shipment_id' => "s-$shipment_id",
                               'pause'       => 0 },
            }]
        });
        # shipment should not be on hold.
        ok ($shipment->discard_changes->is_processing, 'shipment not on hold')
            or diag 'shipment is ' . $shipment->shipment_status->status;

        # Picking commenced should have fixed the race condition for our
        # cancelled item from 'Cancelled' to 'Cancel Pending'
        my $si = $shipment->search_related('shipment_items', { variant_id => $test->{pid}{variant}->id })->single;
        ok ($si->is_cancel_pending, 'shipment item is cancel pending')
            or diag 'shipment item is ' . $si->shipment_item_status->status;

        # We expect -1 as $variant->current_stock_channel includes 'Cancel Pending' stock
        is($new_stock-1, $current_stock, "stock is now $new_stock");
        next;
    }

    if ($test->{type} eq 'sample'){
        $xt_to_wms->expect_messages({
            messages => [{
                '@type'   => 'shipment_cancel',
                'details' => { 'shipment_id' => "s-$shipment_id"},
            }]
        });

        $shipment->discard_changes;
        ok($shipment->is_cancelled, "Shipment is now cancelled");
        is($shipment->canceled_items->count, 1, "shipment has cancelled item");
        # sample stock transfer should be cancelled
        $shipment->stock_transfer->discard_changes; # I there has to be a RC somewhere ...
        ok($shipment->stock_transfer->is_cancelled, 'stock transfer is now cancelled');
    } else {
        # now shipment should be on hold
        $shipment->discard_changes;
        ok ($shipment->is_held, 'shipment on hold')
            or diag 'shipment is ' . $shipment->shipment_status->status;
    }
    # inventory should not change
    is($new_stock, $current_stock, "stock is now $new_stock");
}

done_testing;

package Test::NAP::CancelShipmentWhilePicking;

use NAP::policy "tt", 'test';

=head1 NAME

Test::NAP::CancelShipmentWhilePicking - Cancel Shipment while Picking

=head1 DESCRIPTION

Cancel Shipment while Picking.

#TAGS fulfilment picking iws checkruncondition orderview

=head1 METHODS

=cut

use FindBin::libs;


use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;

use parent 'NAP::Test::Class';

use Test::XTracker::RunCondition export => [qw /$iws_rollout_phase $prl_rollout_phase/];

use Data::Dump  qw( pp );

use XTracker::Database::Shipment qw (get_shipment_item_by_sku);
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :shipment_item_status
    :shipment_status
);


use Test::XT::Flow;
use Test::XTracker::Data;
use Test::XTracker::Artifacts::RAVNI;

sub startup : Test(startup => 1) {
    my ( $self ) = @_;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Fulfilment',
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Flow::WMS',
        ],
    );
    $self->{framework}->login_with_permissions({
        dept => 'Distribution Management',
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Fulfilment/Packing',
            'Fulfilment/Packing Exception',
            'Fulfilment/Picking',
            'Fulfilment/Selection',
            'Customer Care/Order Search',
            'Customer Care/Customer Search',
        ]}
    });

    $self->{schema} = Test::XTracker::Data->get_schema;

    $self->{channel} = Test::XTracker::Data->channel_for_nap;
    $self->{channel_id} = $self->{channel}->id;
}

=head2 test_cancel_after_picking_commence_no_incomplete_pick

=cut

sub test_cancel_after_picking_commence_no_incomplete_pick : Tests {
    my ( $self ) = @_;

    my $framework = $self->{framework};

    my $mech = $framework->mech;
    my ($channel,$pids) = Test::XTracker::Data->grab_products({
                                    how_many => 3,
                          });
    push @{$pids}, $pids->[0];
    my $product_data = $framework->flow_db__fulfilment__create_order( products => $pids, channel => $channel);
    my $shipment_id = $product_data->{shipment_id};
    my $shipment_id_str="s-$shipment_id";
    my $shipment = $self->{schema}->resultset('Public::Shipment')->find($shipment_id);

    Test::XTracker::Data::Order->select_order($shipment->order->discard_changes);

    # By default, items go to CANCELLED when they're cancelled
    my $expected_status_after_cancellation = $SHIPMENT_ITEM_STATUS__CANCELLED;

    if ($iws_rollout_phase) {
        $framework->flow_wms__send_picking_commenced( $shipment );
        # If we're already picking in IWS, the status should be cancel pending
        $expected_status_after_cancellation = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
    } elsif ($prl_rollout_phase) {
        # in the non-test world, this is set when the pick method is called
        # on the allocation, but that doesn't happen in tests
        $shipment->update({'is_picking_commenced' => 1});
        # If we're already picking in a PRL, the status should be cancel pending
        $expected_status_after_cancellation = $SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
    }

    my $items  = [ map { $_->{sku} } @{ $product_data->{'product_objects'} } ];

    is ($shipment->shipment_status_id, $SHIPMENT_STATUS__PROCESSING, 'shipment PROCESSING');

    $framework
        ->flow_mech__customercare__orderview( $product_data->{order_object}->id )
        ->flow_mech__customercare__cancel_shipment_item()
        ->flow_mech__customercare__cancel_item_submit(
            $items->[0]
        )->flow_mech__customercare__cancel_item_email_submit;

    my $variant = $self->{schema}->resultset('Public::Variant')->find_by_sku($items->[0])
                       || $self->{schema}->resultset('Voucher::Variant')->find_by_sku($items->[0]);
    my $shipment_item_rs = $shipment->shipment_items->search({variant_id => $variant->id});
    my $count = 0;
    my $cancelled_ship_item;
    while (my $si = $shipment_item_rs->next){
        if ($si->shipment_item_status_id == $expected_status_after_cancellation){
            $count++;
            $cancelled_ship_item = $si;
        }
    }
    is ($count, 1 , "We have one item with the correct cancelled status");

    ## Pick the shipment
    $framework->task__picking($shipment);

    is ($cancelled_ship_item->shipment_item_status_id, $expected_status_after_cancellation, "Correct shipment item status after picking");

    $framework
     ->flow_mech__customercare__cancel_order( $product_data->{order_object}->id )
     ->flow_mech__customercare__cancel_order_submit
     ->flow_mech__customercare__cancel_order_email_submit;

     is( $framework->mech->as_data->{'meta_data'}->{'Order Details'}->{'Order Status'},
     'Cancelled', 'Order has been cancelled');

}

=head2 test_cancel_after_picking_commence_with_incomplete_pick

=cut

sub test_cancel_after_picking_commence_with_incomplete_pick : Tests {
    my ( $self )  = @_;

    # incomplete_pick is an IWS thing
    # TODO: test the equivalent PRL scenario
    return unless ($iws_rollout_phase);

    my $framework = $self->{framework};
    my $mech = $framework->mech;
    my ($channel,$pids) = Test::XTracker::Data->grab_products({
                                    how_many => 3,
                          });
    push @{$pids}, $pids->[0];
    my $product_data = $framework->flow_db__fulfilment__create_order( products => $pids, channel => $channel);
    my $shipment_id = $product_data->{shipment_id};
    my $shipment_id_str="s-$shipment_id";
    my $shipment = $self->{schema}->resultset('Public::Shipment')->find($shipment_id);

    Test::XTracker::Data::Order->select_order($shipment->order->discard_changes);
    $framework->flow_wms__send_picking_commenced( $shipment );
    my $items  = [ map { $_->{sku} } @{ $product_data->{'product_objects'} } ];

    $framework->flow_wms__send_incomplete_pick(
        shipment_id => $shipment_id,
        operator_id => $APPLICATION_OPERATOR_ID,
        items       => [$items->[0]],
    );
    $shipment = $self->{schema}->resultset('Public::Shipment')->find($shipment_id);
    is ($shipment->shipment_status_id, $SHIPMENT_STATUS__HOLD, 'shipment on hold');
    is ($shipment->is_picking_commenced, 1 , 'flag as picking commenced');

    $framework
        ->flow_mech__customercare__orderview( $product_data->{order_object}->id )
        ->flow_mech__customercare__cancel_shipment_item()
        ->flow_mech__customercare__cancel_item_submit(
            $items->[0]
        )->flow_mech__customercare__cancel_item_email_submit;

    my $variant = $self->{schema}->resultset('Public::Variant')->find_by_sku($items->[0])
                       || $self->{schema}->resultset('Voucher::Variant')->find_by_sku($items->[0]);
    my $shipment_item_rs = $shipment->shipment_items->search({variant_id => $variant->id});
    my $count = 0;
    my $cancelled_ship_item;
    while (my $si = $shipment_item_rs->next){
        if ($si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCELLED){
            $count++;
            $cancelled_ship_item = $si;
        }
    }
    is ($count, 1 , "PC and  IP, item should be Cancelled");

    ## Pick the shipment
    my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );

    my $container = {
        $container_id => [ map { $_->{sku} } @{ $product_data->{'product_objects'} } ],
    };
    $framework->flow_wms__send_shipment_ready(
        shipment_id => $shipment->id,
        container => $container,
    );

    is ($cancelled_ship_item->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__CANCELLED, "Correct shipment item status  after picking");
}

=head2 test_cancel_all_items_after_picking_commence_with_incomplete_pick

=cut

sub test_cancel_all_items_after_picking_commence_with_incomplete_pick : Tests {
    my ( $self )  = @_;

    # incomplete_pick is an IWS thing
    # TODO: test the equivalent PRL scenario
    return unless ($iws_rollout_phase);

    my $framework = $self->{framework};
    my $mech = $framework->mech;
    my ($channel,$pids) = Test::XTracker::Data->grab_products({
                                    how_many => 3,
                          });
    push @{$pids}, $pids->[0];
    my $product_data = $framework->flow_db__fulfilment__create_order( products => $pids, channel => $channel);
    my $shipment_id = $product_data->{shipment_id};
    my $shipment_id_str="s-$shipment_id";
    my $shipment = $self->{schema}->resultset('Public::Shipment')->find($shipment_id);

    {
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework
        ->flow_mech__fulfilment__selection
        ->flow_mech__fulfilment__selection_submit( $shipment_id );

    $xt_to_wms->expect_messages( {
        messages => [ { '@type'   => 'shipment_request',
                        'details' => { shipment_id => $shipment_id_str }
                      } ]
    } );
    }
    $framework->flow_wms__send_picking_commenced( $shipment );

    my $items  = [ map { $_->{sku} } @{ $product_data->{'product_objects'} } ];
    $framework->flow_wms__send_incomplete_pick(
        shipment_id => $shipment_id,
        operator_id => $APPLICATION_OPERATOR_ID,
        items       => [$items->[0]],
    );

    $shipment = $self->{schema}->resultset('Public::Shipment')->find($shipment_id);
    is ($shipment->shipment_status_id, $SHIPMENT_STATUS__HOLD, 'shipment on hold');
    is ($shipment->is_picking_commenced, 1 , 'flag as picking commenced');

    $framework
        ->flow_mech__customercare__orderview( $product_data->{order_object}->id )
        ->flow_mech__customercare__cancel_order($product_data->{order_object}->id)
        ->flow_mech__customercare__cancel_order_submit()
        ->flow_mech__customercare__cancel_order_email_submit;

    my $variant = $self->{schema}->resultset('Public::Variant')->find_by_sku($items->[0])
                       || $self->{schema}->resultset('Voucher::Variant')->find_by_sku($items->[0]);
    my $shipment_item_rs = $shipment->shipment_items->search({variant_id => $variant->id});
    my $count_cancelled = 0;
    my $count_cancel_pending = 0;
    while (my $si = $shipment_item_rs->next){
        if ($si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCELLED){
            $count_cancelled++;
        }elsif ($si->shipment_item_status_id == $SHIPMENT_ITEM_STATUS__CANCEL_PENDING){
            $count_cancel_pending++;
        }
    }

    is ($count_cancelled, 1 , "1 item should be Cancelled");
    is ($count_cancel_pending, 1, "1 item should be Cancel Pending");

}

=head2 test_cancel_after_picking_commenced_sent_before_received

We have a race condition when we send a picking commenced message *after* we
have cancelled the item in XT but *before* we receive it in XT. Check that
the item gets set back from 'Cancelled' to 'Cancel Pending' when we consume
the shipment_ready message, so it can then follow the normal Cancel
Pending->Cancelled procedure

=cut

sub test_cancel_after_picking_commenced_sent_before_received : Tests {
    my ( $self )  = @_;

    # race condition is only relevant with IWS
    return unless ($iws_rollout_phase);

    my $framework = $self->{framework};
    my $shipment;
    subtest 'create selected shipment item' => sub {
        my ($channel,$pids) = Test::XTracker::Data->grab_products;
        my $shipment_id = $framework->flow_db__fulfilment__create_order(
            products => $pids, channel => $channel
        )->{shipment_id};
        $shipment = $self->{schema}
                         ->resultset('Public::Shipment')
                         ->find($shipment_id);

        # Select the shipment
        $framework
            ->flow_mech__fulfilment__selection
            ->flow_mech__fulfilment__selection_submit( $shipment->id );
    };

    my $order = $shipment->order;
    my $shipment_item = $shipment->shipment_items->slice(0,0)->single;
    # Cancel the shipment
    $framework
        ->flow_mech__customercare__orderview( $order->id )
        ->flow_mech__customercare__cancel_order($order->id)
        ->flow_mech__customercare__cancel_order_submit()
        ->flow_mech__customercare__cancel_order_email_submit;

    ok( $shipment_item->discard_changes->is_cancelled, q{shipment item should be 'Cancelled'} )
        or diag sprintf 'Shipment item %d is %s', $shipment_item->id, $shipment_item->shipment_item_status->status;
    # Send a picking commenced message
    $framework->flow_wms__send_picking_commenced( $shipment );

    ok( $shipment_item->discard_changes->is_cancel_pending, q{shipment item should be 'Cancel Pending'} )
        or diag sprintf 'Shipment item %d is %s', $shipment_item->id, $shipment_item->shipment_item_status->status;
}

1;

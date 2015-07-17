#!/usr/bin/env perl

=head1 NAME

cancelled_pigeonhole_items_before_packing.t - Cancel pigeonhole items before packing

=head1 DESCRIPTION

    PH = pigeonhole
    PE = packing exception

Cancel one item before packing (variation A):

    Try to pack using the PH of the cancelled item
    Verify user is told to send it to PE
    Try to pack using a non-cancelled item's PH
    Assert we've sent a shipment-received to IWS now
    Pack the other items as normal

Cancel one item before packing (variation B):

    Try to pack using a non-cancelled item's PH initially
    Assert we sent a shipment-received to IWS
    Pack the other items as normal
    Now submit the cancelled item's PH
    Assert we've sent a shipment-received to IWS now
    User is redirected to the empty tote page
    Verify cancelled item has been removed from PH

Cancel entire shipment before packing:

    Scan first PH at packing
    Assert we sent a shipment-received to IWS
    Verify user is told to send it to PE
    Verify first PH status has been updated correctly
    Check that the item is still there, because the PH hasn't been scanned yet
    Then scan
    Verify user is told to send it to PE
    Verify we didn't send extra shipment_received
    Verify item has now been removed from PH

#TAGS fulfilment packing packingexception checkruncondition iws http orderview whm

=cut

use strict;
use warnings;
use FindBin::libs;
use Test::More;
use Test::XTracker::RunCondition iws_phase => 'iws', dc => 'DC1', export => qw( $iws_rollout_phase );


use Test::More::Prefix qw/test_prefix/;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level :container_status );
use XTracker::Database qw(:common);
use Test::XTracker::LocationMigration;
use Test::XTracker::Data qw/qc_fail_string/;
use Test::XT::Data::Container;
use Test::Differences;
use Test::XTracker::Artifacts::RAVNI;
use JSON::XS;
use XTracker::Config::Local 'config_var';

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
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
    dept => 'Customer Care',
});

my $schema = Test::XTracker::Data->get_schema;

my $product_count = 3; # how many products we want in each order
my ($shipment, $p_container_ids, $product_data);

cancel_one_item_A();
cancel_one_item_B();
cancel_entire_shipment();

done_testing();

sub cancel_one_item_A {
    # Cancel one item before packing
    test_prefix('Cancel item: A');
    ($shipment, $p_container_ids, $product_data) = create_picked_ph_shipment();


    {
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework
        ->flow_mech__customercare__orderview( $shipment->order->id )
        ->flow_mech__customercare__cancel_shipment_item()
        ->flow_mech__customercare__cancel_item_submit($product_data->{'product_objects'}->[0]->{sku})
        ->flow_mech__customercare__cancel_item_email_submit;

    # We should've re-sent the shipment_request with the latest info
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'   => 'shipment_request',
                'details' => { 'shipment_id' => "s-".$shipment->id, },
            },
        ]
    });
    }
    #print $framework->mech->uri()."\ncontinue?\n"; my $s=<>;

    # Try to pack using the ph of the cancelled item
    $framework->errors_are_fatal(0);
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $p_container_ids->[0] );
    $framework->errors_are_fatal(1);

    # We shouldn't be sending a shipment_received yet, it'll happen when they scan
    # one of the other ph ids

    # Yes, this assumes the shipment will only have one shipment_item
    # for each sku/variant, but so does flow_mech__customercare__cancel_item_submit
    my $shipment_item_cancelled = $shipment->shipment_items->search({
        variant_id => $product_data->{'product_objects'}->[0]->{variant_id},
    })->first;
    is ($shipment_item_cancelled->container_id(), $p_container_ids->[0], 'shipment item is still in pigeon hole in xtracker db');
    is ($shipment_item_cancelled->container->status_id(), $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS, 'container status has been set to Superfluous Items');

    # Check user is told to send it to PE
    is($framework->mech->app_error_message,
         'This pigeon hole is not associated with a shipment. Please ensure the item has been returned to the same pigeon hole, then take the pigeon hole barcode to packing exception.',
         'packer told to take item to PE');

    # Try to pack using a non-cancelled item's ph id
    {
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $p_container_ids->[1] )
        ->flow_task__fulfilment__packing_accumulator( @$p_container_ids[1,2] );

    # Assert we've sent a shipment-received to IWS now
    $xt_to_wms->expect_messages({
        messages => [
            {
                'type'   => 'shipment_received',
            },
        ]
    });
    }

    # Pack the other items as normal
    $framework->flow_mech__fulfilment__packing_checkshipment_submit();

    for my $item (@{ $product_data->{'product_objects'} }[1,2]) {
        my $sku      = $item->{'sku'};
        $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $sku );
    }
    {
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $product_data->{channel_object}->id )
        ->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
        ->flow_mech__fulfilment__packing_packshipment_complete;

    $xt_to_wms->expect_messages({
        messages => [
            {
                'type'   => 'shipment_packed',
                'details' => { shipment_id => "s-".$shipment->id }
            },
    ]
    });
    }
}


sub cancel_one_item_B {
    # Cancel one item before packing
    test_prefix('Cancel item: B');
    ($shipment, $p_container_ids, $product_data) = create_picked_ph_shipment();

    {
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework
        ->flow_mech__customercare__orderview( $shipment->order->id )
        ->flow_mech__customercare__cancel_shipment_item()
        ->flow_mech__customercare__cancel_item_submit($product_data->{'product_objects'}->[0]->{sku})
        ->flow_mech__customercare__cancel_item_email_submit;

    # We should've re-sent the shipment_request with the latest info
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'   => 'shipment_request',
                'details' => { 'shipment_id' => "s-".$shipment->id, },
            },
        ]
    });

    # Try to pack using a non-cancelled item's ph id initially
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $p_container_ids->[1] )
        ->flow_task__fulfilment__packing_accumulator( @$p_container_ids );

    # Assert we sent a shipment-received to IWS
    $xt_to_wms->expect_messages({
        messages => [
            {
                'type'   => 'shipment_received',
            },
        ]
    });
    }

    #print $framework->mech->uri()."\ndo the packing, then continue?\n"; my $s=<>;
    # Pack the other items as normal
    $framework->flow_mech__fulfilment__packing_checkshipment_submit();

    for my $item (@{ $product_data->{'product_objects'} }[1,2]) {
        my $sku      = $item->{'sku'};
        $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $sku );
    }
    {
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $product_data->{channel_object}->id )
        ->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
        ->flow_mech__fulfilment__packing_packshipment_complete;

    $xt_to_wms->expect_messages({
        messages => [
            {
                'type'   => 'shipment_packed',
                'details' => { shipment_id => "s-".$shipment->id }
            },
        ]
    });
    }

    # Now submit the cancelled item's ph id
    # A real user would've been redirected to the empty tote page with js
    # but since we have no test methods to parse and execute js yet, we'll
    # do it this way instead.
    $framework->errors_are_fatal(0);
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $p_container_ids->[0] );
    $framework->errors_are_fatal(1);
    is($framework->mech->app_error_message,
         'This pigeon hole is not associated with a shipment. Please ensure the item has been returned to the same pigeon hole, then take the pigeon hole barcode to packing exception.',
         'packer told to take item to PE');

    # Check cancelled item has been removed from ph in xt

    # Yes, this assumes the shipment will only have one shipment_item
    # for each sku/variant, but so does flow_mech__customercare__cancel_item_submit
    my $shipment_item_cancelled = $shipment->shipment_items->search({
        variant_id => $product_data->{'product_objects'}->[0]->{variant_id},
    })->first;
    is ($shipment_item_cancelled->container_id(), $p_container_ids->[0], 'shipment item is still in pigeon hole in xtracker db');
    is ($shipment_item_cancelled->container->status_id(), $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS, 'container status has been set to Superfluous Items');
}


sub cancel_entire_shipment {
    # Cancel entire shipment before packing
    test_prefix('Cancel shipment before packing');
    ($shipment, $p_container_ids, $product_data) = create_picked_ph_shipment();

    #print $framework->mech->uri()."\ncontinue?\n"; my $s=<>;

    my $first_ph;
    {
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework
        ->flow_mech__customercare__cancel_order( $shipment->order->id )
        ->flow_mech__customercare__cancel_order_submit
        ->flow_mech__customercare__cancel_order_email_submit;

    is( $framework->mech->as_data->{'meta_data'}->{'Order Details'}->{'Order Status'},
        'Cancelled', 'Order has been cancelled');
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'   => 'shipment_cancel',
                'details' => { 'shipment_id' => "s-".$shipment->id, },
            },
        ]
    });

    # Scan first pigeon hole id at packing
    $first_ph = shift @$p_container_ids;
    $framework->errors_are_fatal(0);
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $first_ph );
    $framework->errors_are_fatal(1);

    # Assert we sent a shipment-received to IWS
    $xt_to_wms->expect_messages({
        messages => [
            {
                'type'   => 'shipment_received',
            },
        ]
    });
    }

    # Check user is told to send it to PE
    is($framework->mech->app_error_message,
         'This pigeon hole is not associated with a shipment. Please ensure the item has been returned to the same pigeon hole, then take the pigeon hole barcode to packing exception.',
         'packer told to take item to PE');

    # Check first ph status has been updated correctly
    my $shipment_item_cancelled = $shipment->shipment_items->search({
        container_id => $first_ph,
    })->first;
    is ($shipment_item_cancelled->container_id(), $first_ph, 'shipment item is still in pigeon hole in xtracker db');
    is ($shipment_item_cancelled->container->status_id(), $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS, 'container status has been set to Superfluous Items');


    foreach my $ph_id (@$p_container_ids) {
        # First check that the item is still there, because the ph
        # hasn't been scanned yet
        note "checking $ph_id";
        $shipment_item_cancelled = $shipment->shipment_items->search({
            'container_id' => $ph_id
        })->first;
        is ($shipment_item_cancelled->container->status_id(), $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS, 'shipment item is still in pigeon hole, pigeon hole status is Picked Items');

        # Then scan
        $framework->errors_are_fatal(0);
        $framework
            ->flow_mech__fulfilment__packing
            ->flow_mech__fulfilment__packing_submit( $ph_id );
        $framework->errors_are_fatal(1);
        # Check user is told to send it to PE
        is($framework->mech->app_error_message,
             'This pigeon hole is not associated with a shipment. Please ensure the item has been returned to the same pigeon hole, then take the pigeon hole barcode to packing exception.',
             'packer told to take item to PE');

        # Check we didn't send extra shipment_received

        # Check item has now been removed from ph in xt
        $shipment_item_cancelled->discard_changes();
        is ($shipment_item_cancelled->container_id(), $ph_id, 'shipment item is still in pigeon hole in xtracker db');
        is ($shipment_item_cancelled->container->status_id(), $PUBLIC_CONTAINER_STATUS__SUPERFLUOUS_ITEMS, 'container status has been set to Superfluous Items');
    }
}


sub create_picked_ph_shipment {
    # Create the order with three products
    my $product_data =
        $framework->flow_db__fulfilment__create_order_selected(
            products => $product_count,
            channel  => 'NAP'
        );
    my $shipment_id = $product_data->{'shipment_id'};
    my @p_container_ids = Test::XT::Data::Container->get_unique_ids({
        how_many => 3,
        prefix   => 'PH7357',
    });

    # Fake a ShipmentReady from IWS
    $framework->flow_wms__send_shipment_ready(
        shipment_id => $shipment_id,
        container => {
            $p_container_ids[0] => [ map { $_->{'sku'} } @{ $product_data->{'product_objects'} }[0] ],
            $p_container_ids[1] => [ map { $_->{'sku'} } @{ $product_data->{'product_objects'} }[1] ],
            $p_container_ids[2] => [ map { $_->{'sku'} } @{ $product_data->{'product_objects'} }[2] ],
        },
    );

    my $shipment = $schema->resultset('Public::Shipment')->find($shipment_id);

    return ($shipment, \@p_container_ids, $product_data);
}


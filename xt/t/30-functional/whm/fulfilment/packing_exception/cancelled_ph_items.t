#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

cancelled_ph_items.t - Test cancelling pigeonhole items at packing

=head1 DESCRIPTION

ph = pigeonhole, a place to store stock

Cancelled at Packing Exception, Lost in Paris...

This is just like cancelled_items.t but with pigeon holes instead of totes.
Maybe we should combine the tests.

Pigeon holes are currently used only with IWS.

#TAGS fulfilment packing packingexception iws duplication checkruncondition whm

=head1 SEE ALSO

cancelled_items.t

=cut

use Test::XTracker::RunCondition iws_phase => 'iws', dc => 'DC1', export => qw( $iws_rollout_phase );

use Data::Dumper;


use Test::Differences;
use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use XTracker::Config::Local 'config_var';
use Test::XTracker::Artifacts::RAVNI;
use JSON::XS ();

test_prefix('Setup');

# Start-up gubbins here. Test plan follows later in the code...
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::AppMessages',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::WMS',
        'Test::XT::Flow::CustomerCare'

    ],
);

$framework->clear_sticky_pages;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 4 });
my %products = map {; "P$_" => shift( @$pids ) } 1..(scalar @$pids);
my @pigeonholes = Test::XT::Data::Container->get_unique_ids({
    prefix   => 'PH7357',
    how_many => 4,
});
my %pigeonholes = map {; "PH$_" => shift( @pigeonholes ) } 1..(scalar @pigeonholes);

my $order_data = $framework->flow_db__fulfilment__create_order_selected(
    channel  => $channel,
    products => [ @products{ 'P1' .. 'P4' } ],
);
my $shipment = $order_data->{'shipment_object'};
my $order = $order_data->{'order_object'};

# Fake a ShipmentReady from IWS
$framework->flow_wms__send_shipment_ready(
    shipment_id => $shipment->id,
    container => {
        $pigeonholes{"PH1"} => [ $products{"P1"}->{'sku'}],
        $pigeonholes{"PH2"} => [ $products{"P2"}->{'sku'}],
        $pigeonholes{"PH3"} => [ $products{"P3"}->{'sku'}],
        $pigeonholes{"PH4"} => [ $products{"P4"}->{'sku'}],
    },
);




act1();
done_testing();

# Act 1
# -----
# ... in which our hero (PH1) contains one shipment (S1) of 4 items (P1..P4), two
# of which get failed (P1, P2) at Packing, and two of which (P1, P3) get
# cancelled on their way to the Packing Exception desk.
#
# At this point:
# P1 - Cancel-pending item, no faulty/non-faulty status
# P2 - Faulty item
# P3 - Cancel-pending item, no faulty/non-faulty status
# P4 - Just fine
#
# All four items are displayed at Packing Exception. P1 and P3 are marked as
# 'Cancelled'. The user is prompted to scan them out of the tote. The user must
# scan these to what XTracker believes is an empty tote (T2). In Phase 0, this
# means no further action beyond the tote dissociation is needed. In Phase 1 and
# Phase 2, we cancel the items and update web stock.

sub act1 {
    test_prefix('Act 1 - Setup');
    # Pack the shipment
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $pigeonholes{'PH1'} )
        ->flow_task__fulfilment__packing_accumulator( values %pigeonholes );

    # Assert we sent a shipment-received to IWS
    $xt_to_wms->expect_messages({
        messages => [
            {
                'type'   => 'shipment_received',
            },
        ]
    });


    # Fail P1 and P2
    $framework
        ->catch_error(
            "Please return pigeon hole items to their original pigeon holes and take any labels and paperwork to the packing exception desk",
            "Send to packing exception message issued",
            flow_mech__fulfilment__packing_checkshipment_submit => (
                fail => {
                    sku('P1') => "Has clearly been on fire at some point",
                    sku('P2') => "Muppet fur is the wrong texture"
                }
            )
        );

    # Check the status of the shipment items are as expected
    test_pigeonhole_items (
        "Shipment items in correct state after Check Shipment",
        [ $pigeonholes{'PH1'}, $pigeonholes{'PH2'}, $pigeonholes{'PH3'}, $pigeonholes{'PH4'} ],
        [
            [ $products{'P1'}->{variant_id}, $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ],
            [ $products{'P2'}->{variant_id}, $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ],
            [ $products{'P3'}->{variant_id}, $SHIPMENT_ITEM_STATUS__PICKED ],
            [ $products{'P4'}->{variant_id}, $SHIPMENT_ITEM_STATUS__PICKED ],
        ],
        $shipment
    );



    # We should be in PIPE...
    $framework->assert_location(qr!/Fulfilment/Packing/PlaceInPEtote!);
    for ( 'P1' .. 'P4' ) {
        $framework
            ->flow_mech__fulfilment__packing_placeinpetote_scan_item( sku( $_ ) )
            ->flow_mech__fulfilment__packing_placeinpetote_pigeonhole_confirm();
    }
    $framework->test_mech__app_info_message__like(qr!to the packing exception desk!);
    $framework->flow_mech__fulfilment__packing_placeinpetote_mark_complete;

    $xt_to_wms->expect_messages({
        messages => [
            {
                'type'   => 'shipment_reject',
            },
        ]
    });

    # Cancel P1 and P3
    $framework
        ->flow_mech__customercare__orderview( $order->id )
        ->flow_mech__customercare__cancel_shipment_item()
        ->flow_mech__customercare__cancel_item_submit(
            sku('P1'), sku('P3')
        )->flow_mech__customercare__cancel_item_email_submit;

    # We should've re-sent the shipment_request with the latest info
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'   => 'shipment_request',
                'details' => { 'shipment_id' => "s-".$shipment->id, },
            },
        ]
    });


    # Check the status of the shipment items are as expected
    test_pigeonhole_items (
        "Shipment items in correct state after cancellations",
        [ $pigeonholes{'PH1'}, $pigeonholes{'PH2'}, $pigeonholes{'PH3'}, $pigeonholes{'PH4'} ],
        [
            [ $products{'P1'}->{variant_id}, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING ],
            [ $products{'P2'}->{variant_id}, $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ],
            [ $products{'P3'}->{variant_id}, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING ],
            [ $products{'P4'}->{variant_id}, $SHIPMENT_ITEM_STATUS__PICKED ],
        ],
        $shipment
    );


    # Open the shipment at PE Desk, and check that we see P1 and P3 as
    #   cancelled, P2 as QC fail, and P4 as QC pass
    test_prefix('Act 1 - Tests');
    $framework
        ->flow_mech__fulfilment__packingexception
        ->flow_mech__fulfilment__packingexception_submit( $pigeonholes{'PH1'} );


    my @shipment_items = @{$framework->mech->as_data->{'shipment_items'}};
    is( scalar @shipment_items, 4, "Four items are shown" );

    # Check what's on the page is what we think it should be
    eq_or_diff(
        [ map { [sku($_) => status_by_sku(sku($_), @shipment_items ) ] } 'P1'..'P4' ],
        [
            [sku('P1') => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING    ],
            [sku('P2') => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ],
            [sku('P3') => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING    ],
            [sku('P4') => $SHIPMENT_ITEM_STATUS__PICKED            ],
        ],
        "Displayed items are correct"
    );

    # Scan P1 and P3 in to a tote - the tote shouldn't record them in XTracker,
    #   and this only works with 'empty' pigeonholes
    for my $pid ('P1', 'P3') {
        my $ph = $pid;
        $ph =~ s/P/PH/;
        $framework
            ->flow_mech__fulfilment__packingexception_shipment_item_mark_putaway( sku($pid) )
            ->flow_mech__fulfilment__packing_scanoutpeitem_sku( sku($pid) );
        like($framework->mech->as_data->{scan_form}->{Action},
            qr/^Return item to pigeon hole $pigeonholes{$ph}/,
            'User told to return item to same pigeon hole');
        $framework->flow_mech__fulfilment__packingexception_scanoutpeitem__pigeonhole_confirm();
        $framework->test_mech__app_status_message__is(
            'Cancelled Item in ' . $pigeonholes{$ph} . ' marked as ready for IWS to process',
            "WHM-51: Pigeon-hole specific cancelled item putaway msg shown"
        );

    }

    # Check PE Desk shows P2 as failed, P4 as QC pass
    @shipment_items = @{$framework->mech->as_data->{'shipment_items'}};
    is( scalar @shipment_items, 2, "Two items are shown" );
    eq_or_diff(
        [ map { [sku($_) => status_by_sku(sku($_), @shipment_items ) ] } 'P2','P4' ],
        [
            [sku('P2') => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ],
            [sku('P4') => $SHIPMENT_ITEM_STATUS__PICKED            ],
        ],
        "Displayed items are correct"
    );

    # Scan out P2 to a faulty tote
    $framework
        ->flow_mech__fulfilment__packing_checkshipmentexception_faulty( sku('P2') )
        ->flow_mech__fulfilment__packing_scanoutpeitem_sku( sku('P2') );
    like($framework->mech->as_data->{scan_form}->{Action}, qr/Put item to one side/, 'User told to put item to one side');;
    $framework
        ->flow_mech__fulfilment__packingexception_scanoutpeitem__pigeonhole_confirm();

    # TODO: check we sent item_moved from ph to faulty tote
    # We should've re-sent the shipment_request with the latest info
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'   => 'item_moved',
                'details' => {
                    'shipment_id' => "s-".$shipment->id,
                    'items' => [{'sku' => sku('P2'), 'quantity' => 1}],
                    'from' => {'container_id' => $pigeonholes{'PH2'}},
                    'to' => {'container_id' => 'M01', 'stock_status' => 'faulty'},
                },
            },
        ]
    });


    # Say we're done with the tote
    $framework->flow_mech__fulfilment__packing_checkshipmentexception_submit();

    # We should've send a shipment_pause: false too
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'   => 'shipment_wms_pause',
                'details' => {
                    'shipment_id' => "s-".$shipment->id,
                    'pause' => JSON::XS::false,
                },
            },
        ]
    });
}

sub test_pigeonhole_items {
    my ( $test_name, $pigeonhole_ids, $items, $shipment ) = @_;

    my @db_items;
    my @expected_items;
    foreach my $pigeonhole_id (@$pigeonhole_ids) {
        my $db_item = $shipment->shipment_items->search({
            'container_id' => $pigeonhole_id,
        })->first;
        push @db_items, [$db_item->variant_id, $db_item->shipment_item_status_id];
        push @expected_items, shift @$items;
    }
    eq_or_diff(\@db_items, \@expected_items, $test_name);
}

sub status_by_sku {
    my ($desired, @shipment_items) = @_;
    my ($item) = grep { $_->{'SKU'} eq $desired } @shipment_items;
    ok( $item, "SKU $desired found" );
    if ( $item->{'Actions'} &&
        $item->{'Actions'} =~ m/This item has been cancelled/ ) {
        return $SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
    } elsif ( $item->{'QC'} ne 'Ok' ) {
        return $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION;
    } else {
        return $SHIPMENT_ITEM_STATUS__PICKED;
    }
}

sub sku { return $products{shift()}->{'sku'} };

1;

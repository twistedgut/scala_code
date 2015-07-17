#!/usr/bin/env perl

=head1 NAME

pipeo.t - Test the PIPE-O page ("Place In Packing Exception, Orphan")

=head1 DESCRIPTION

Handler = /Fulfilment/Packing/PlaceInPEOrphan

Creates a shipment which has at least one or more canceled item(s) and also
at least one or more extraneous product(s).

=head2 Bugs

With $prl_rollout_phase = 1, this test does not account for 3 item_moved messages.

With $prl_rollout_phase = 0, this test also does not account for 3 item_moved
messages, and additionally does not account for 1 picking_commenced and
1 shipment_ready message.

#TAGS fulfilment packing packingexception todo iws prl whm

=head1 TODO

Find the correct place to 'expect' the extra messages.

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::RunCondition export => [qw($iws_rollout_phase $prl_rollout_phase)];


use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use XTracker::Config::Local qw( config_var );
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;
use Carp::Always;

test_prefix("Setup");
# Start-up gubbins here. Test plan follows later in the code...
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::WMS',
        'Test::XT::Flow::PRL',
    ],
);
my $t=$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Picking',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

my $how_many_pids = 5;
# my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => $how_many_pids });
# my %products = map {; "P$_" => shift( @$pids ) } 1..$how_many_pids;
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 5, phys_vouchers => { how_many => 2,want_stock => 3} });
# 5 regular products, 2 vouchers
my %products = map {; "P$_" => shift( @$pids ) } 1..7;
note "Products:";
note "\t" . $_ . ': ' . $products{$_}->{'sku'} for sort keys %products;

my %shipments;
# Create an order of products excluding a regular PID P5 and a voucher P7
# We will want these two to be dealt with as Orphans
if ($iws_rollout_phase || $prl_rollout_phase) {
    $shipments{"S1"} = $framework->flow_db__fulfilment__create_order_selected(
        channel  => $channel,
        products => [ @products{qw/P1 P2 P3 P4 P6/} ],
    );
} else {
    $shipments{"S1"} = $framework->flow_db__fulfilment__create_order(
        channel  => $channel,
        products => [ @products{qw/P1 P2 P3 P4 P6/} ],
    );
}

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

# Pack all of these in to tote T1
# Get a tote T2 which will be used for the Orphan items

my %totes;
my $count;
# Create 2 totes. T!
for my $tote_id ( Test::XT::Data::Container->get_unique_ids( { how_many => 2 } )) {
    $totes{"T" . ++$count} = $tote_id;
}


# Fake a ShipmentReady from IWS
my $shipment_id = $shipments{'S1'}->{'shipment_id'};
my $shipment_ob = $shipments{'S1'}->{'shipment_object'};

test_prefix("Picking S1");
note "Packing S1 [$shipment_id]";

if ($iws_rollout_phase) {
    $framework->flow_wms__send_shipment_ready(
        shipment_id => $shipment_id,
        container => {
            $totes{'T1'} => [ map { $_->{'sku'} } @{ $shipments{'S1'}->{product_objects} } ]
        },
    );
} elsif ($prl_rollout_phase) {
    $framework->flow_msg__prl__pick_shipment(
        shipment_id => $shipment_id,
        container => {
            $totes{'T1'} => [ map { $_->{'sku'} } @{ $shipments{'S1'}->{'product_objects'} } ]
        },
    );
    $framework->flow_msg__prl__induct_shipment( shipment_id => $shipment_id );
} else {
    # Select the order, and start the picking process
    my $picking_sheet =
        $framework->flow_task__fulfilment__select_shipment_return_printdoc( $shipment_id );

    $framework
        ->flow_mech__fulfilment__picking # /Fulfilment/Picking
        ->flow_mech__fulfilment__picking_submit( $shipment_id );

    # Pick the items according to the pick-sheet
    for my $item (@{ $picking_sheet->{'item_list'} }) {
        my $location = $item->{'Location'};
        my $sku      = $item->{'SKU'};
        my $tote_id  = $totes{'T1'};

        $framework->flow_mech__fulfilment__picking_pickshipment_submit_location( $location );
        $framework->flow_mech__fulfilment__picking_pickshipment_submit_sku( $sku );
        $framework->flow_mech__fulfilment__picking_pickshipment_submit_container( $tote_id );
    }
}

note('The shipment has now been picked');

# Canceling products
note "Cancelling Product 2,3 and Voucher 6 from Shipment 1";

$framework->flow_mech__customercare__orderview( $shipments{'S1'}->{'order_object'}->id )
    ->flow_mech__customercare__cancel_shipment_item;

$framework->flow_mech__customercare__orderview( $shipments{'S1'}->{'order_object'}->id )
    ->flow_mech__customercare__cancel_shipment_item()
    ->flow_mech__customercare__cancel_item_submit(
        $products{'P2'}->{'sku'},
        $products{'P3'}->{'sku'},
        $products{'P6'}->{'sku'} )
    ->flow_mech__customercare__cancel_item_email_submit();

note('About to go over the packing workflow');

$framework->mech__fulfilment__set_packing_station( $channel->id );

# NOTE: Stop here if you want to manually complete packing

note('QC step, mark each item as "ok"');

$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $totes{'T1'} )
    ->flow_mech__fulfilment__packing_checkshipment_submit();

note('Pack each item');
# NOTE: This test ignores the javascript validation for SKUs,
# so if you're doing this manually with test SKUs of the format 1-232,
# you'll need to disable javascript in your browser

# NOTE: When doing this manually, only P1 and P4 are displayed, no other SKU is shown
# Maybe P5 always fails i.e. xt_warn("The sku entered could not be found in this shipment.  Please try again.")
# ...and this test just ignores the error?
for my $prod_index(qw( P1 P4 P5 )) {
    my $sku      = $products{$prod_index}->{'sku'};
    note "Packing $prod_index: " . $sku;
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $sku );
}

$framework
    # Assign Box to Packed Items:
    ->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $channel->id )
    # Airway Bill question does not appear, so the follow call does nothing,
    # see XTracker::Database::Distribution::AWBs_are_present:
    ->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789", $shipment_id)
    # hit the big green 'Complete Packing' button:
    ->flow_mech__fulfilment__packing_packshipment_complete;

# Here we see: xt_info('This shipment did not go through Carrier Automation
#   but has still completed packing please take it to the Shipping Area.');
#   -> Continue button

# ...ignore that and re-enter the page...

# At this point we have 3 canceled shipment items in a tote
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $totes{'T1'} )
    # "The tote listed below should be empty. Please confirm tote is empty."
    # Choices: No (items remaining) / Yes (totes empty)
    ->flow_mech__fulfilment__packing_emptytote_submit('no');

like($framework->mech->app_info_message,
     qr{Please scan unexpected item},
     'packer asked to send shipment to exception desk');

# We should now be at the PIPE-O page

# Let's move the items to the new container about to be sent to Packing Exception.
# But first let's check it handles being passed some complete crap...
test_prefix("Throwing junk at PIPE-O");
for (
    ['Badly-formed variant', 'PETER4EVER', qr/sku is not valid/],
    ['Non-existant variant', '0-000',      qr/sku is not valid/]
) {
    my ( $name, $sku, $match ) = @$_;
    $framework->catch_error( $match, $name,
        flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item => $sku );
}

# Account for messages sent up till now...
if ($iws_rollout_phase) {
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'       => "shipment_request",
                'details'     => {
                    shipment_id    => "s-$shipment_id",
                    shipment_type  => "customer",
                },
            },
            {
                '@type'    => "shipment_received",
                'details'     => {
                    shipment_id => "s-$shipment_id",
                },
            },
            {
                '@type'    => "shipment_packed",
                'details'     => {
                    shipment_id => "s-$shipment_id",
                },
            }
        ]
    });
} elsif ($prl_rollout_phase) {
    # TODO DC2A - when we've done packing exception, say what new messages should've been sent
    # For now it's the same as with IWS except without the shipment_request
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'    => "shipment_received",
                'details'     => {
                    shipment_id => "s-$shipment_id",
                },
            },
            {
                '@type'    => "shipment_packed",
                'details'     => {
                    shipment_id => "s-$shipment_id",
                },
            }
        ]
    });
} else {
    $xt_to_wms->wait_for_new_files(files=>4);
}

test_prefix("Packing PIPE-O");

# Take a detour to test the RouteRequest message:
{
my $xt_to_conveyor = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
$framework
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($products{'P1'}->{'sku'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($totes{'T2'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete
    # Get screen back to how it was before detour:
    ->flow_mech__fulfilment__packing_emptytote_submit('no');
if ($prl_rollout_phase) {
    $xt_to_conveyor->expect_messages({
        messages => [
            {
                '@type' => 'route_request',
            },
        ]
    });
}
}
$xt_to_wms->expect_messages({
    messages => [
        { '@type' => 'route_tote' },
    ]
});
# /detour

# PIPE-O'ing 2/3 cancelled items
# We're leaving one cancelled item in the tote on purpose
$framework
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($products{'P2'}->{'sku'});
$framework->catch_error(
    qr/contains Picked Items and cannot be used/,
    "Try and pack that item in to the tote it was in",
    flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote => $totes{'T1'} );
$framework
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($totes{'T2'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($products{'P6'}->{'sku'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($totes{'T2'});

# PIPE-O'ing the superflous items
$framework
    # Throw an extra strayed item (P5) in T2 too:
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($products{'P5'}->{'sku'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($totes{'T2'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($products{'P7'}->{'sku'})
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($totes{'T2'});

# Assert P3 is still cancel_pending
my $p3_si = $shipment_ob->shipment_items->search({ variant_id =>  $products{'P3'}->{variant_id} }, {rows => 1})->first;
is( $p3_si->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__CANCEL_PENDING, 'Shipment item is cancel_pending' );

# Mark process as done
# and mark the tote as emtpy
$framework
    ->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete
    ->flow_mech__fulfilment__packing_emptytote_submit('yes');

# Assert source tote is empty even though we left a cancelled item P3
my $schema = Test::XTracker::Data->get_schema;
my $source_totes_item_count = $schema->resultset('Public::ShipmentItem')
    ->search({
        container_id => { -in => [ $totes{'T1'} ] },
    })->count;

is($source_totes_item_count,0,"Right number of items remaining in source tote");

# check we sent 'moved' messages
my @messages;
for my $index (qw/P2 P6/) {
    push @messages,{
        '@type'   => 'item_moved',
        'path'    => $iws_rollout_phase == 0 ? qr{/ravni_wms$} : $Test::XTracker::Data::iws_queue_regex,
        'details' => { from => {container_id => $totes{'T1'}},
                       to   => {container_id => $totes{'T2'}, stock_status => 'main'},
                       items => [{ sku => $products{$index}->{'sku'}, }]
                     }
    }
}
# Check we told IWS that we moved the remaining cancel_pending item to 'lost'
push @messages, {
    '@type'   => 'item_moved',
    'path'    => $iws_rollout_phase == 0 ? qr{/ravni_wms$} : $Test::XTracker::Data::iws_queue_regex,
    'details' => { from => {container_id => $totes{'T1'} },
                   to   => {place => 'lost', stock_status => 'main'},
                   items => [{ sku => $products{'P3'}->{sku}, }]
                 }
};

$xt_to_wms->expect_messages({
    messages => \@messages
});

# Check that remaining cancel_pending item is marked as cancelled as it ain't gonna get put away
is($p3_si->discard_changes->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__CANCELLED, 'shipment item is cancelled');


# Let's check that these canceled shipment items are associated with the new tote.
my $peo_tote_shipment_item_count = $schema->resultset('Public::ShipmentItem')
    ->search({
        shipment_id  => $shipments{S1}->{'shipment_id'},
        container_id => { -in => [ $totes{'T2'} ] },
    })->count;

is($peo_tote_shipment_item_count,2,"Right number of canceled shipment items in PEO tote");

my $peo_tote_orphan_item_rs = $schema->resultset('Public::OrphanItem')
    ->search({
        container_id => { -in => [ $totes{'T2'} ] },
    });

is($peo_tote_orphan_item_rs->count,3,"Right number of strayed skus in the tote");
is($peo_tote_orphan_item_rs->slice(0,0)->single->operator->username, $framework->mech->logged_in_as, "Operator name matches");

done_testing;

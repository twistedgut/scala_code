#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

shipment_changes_in_qc.t - Shipment changes during Quality Control

=head1 DESCRIPTION

Shipment changes during Quality Control.

We have two shipments, S1 and S2. We will put P1..P3 in S1, and but S1 in T1.
We will put P4..P6 in S2, and place that in T2.

We'll take both to be packed, but we'll change the order at QC for both.
For S1, we'll cancel the order. This should mean that when the tote is
rescanned (as a consequence of hitting QC), we're asked to confirm tote is
empty. We won't follow through the process, as PIPE-O is tested elsewhere

We'll then do S2, and do a replacement on an item in it, P4 to P7. When we
rescan the tote (which will happen as a consequence of hitting QC), we should
be told to PIPE the two remaining items

#TAGS fulfilment picking packing orderview checkruncondition iws prl whm

=cut

use Test::XTracker::RunCondition dc => 'DC1', export => qw( $iws_rollout_phase );

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data qw/qc_fail_string/;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;


test_prefix("Setup");

# Start-up gubbins here. Test plan follows later in the code...
my @traits = (
        'Test::XT::Feature::AppMessages',
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
);
push @traits, 'Test::XT::Flow::WMS' if ($iws_rollout_phase > 0);
my $framework = Test::XT::Flow->new_with_traits(
    traits => \@traits,
);

$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Picking',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);


# Russle up 7 products
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 7 });
my %products = map {; "P$_" => shift( @$pids ) } 1..(scalar @$pids);

# We're going to make sure that P4 contains more than one variant, as we're
# going to cancel it by swapping it. We'll put the other variant in P7.
my ($new_channel, $variants) =
    Test::XTracker::Data->grab_multi_variant_product({
        channel => $channel,
        ensure_stock => 1
    });
( $products{'P4'}, $products{'P7'} ) = @$variants;


# Knock up our two totes
my %totes;
my $count;
for my $tote_id ( Test::XT::Data::Container->get_unique_ids( { how_many => 2 } )) {
    $totes{"T" . ++$count} = $tote_id;
}

# Create our two shipments and get them ready for packing
my %shipments;

if ($iws_rollout_phase == 0) {
    for my $sid ( 1 .. 2 ) {
        my $p_start = $sid ** 2;

        $shipments{"S$sid"} = $framework->flow_db__fulfilment__create_order(
            channel  => $channel,
            products => [ map { $products{"P$_"} } $p_start..($p_start+2) ],
        )
    }
    # Pick the totes
    foreach ( map { [ $totes{"T$_"}, "S$_" ] } 1 .. 2 ) {
        my $tote_id  = $_->[0];
        my $shipment = $_->[1];

        my $shipment_id = $shipments{$shipment}->{'shipment_id'};
        note "Picking $shipment [$shipment_id]";

        # Select the order, and start the picking process
        my $picking_sheet =
            $framework->flow_task__fulfilment__select_shipment_return_printdoc( $shipment_id );


        $framework
            ->flow_mech__fulfilment__picking
            ->flow_mech__fulfilment__picking_submit( $shipment_id );

        # Pick the items according to the pick-sheet
        for my $item (@{ $picking_sheet->{'item_list'} }) {
            my $location = $item->{'Location'};
            my $sku      = $item->{'SKU'};

            $framework->flow_mech__fulfilment__picking_pickshipment_submit_location( $location );
            $framework->flow_mech__fulfilment__picking_pickshipment_submit_sku( $sku );
            $framework->flow_mech__fulfilment__picking_pickshipment_submit_container( $tote_id );
        }

        $framework->flow_msg__prl__induct_shipment(
            shipment_id => $shipment_id,
        );
    }
} else {
    for my $sid ( 1 .. 2 ) {
        my $p_start = $sid ** 2;

        $shipments{"S$sid"} = $framework->flow_db__fulfilment__create_order_selected(
            channel  => $channel,
            products => [ map { $products{"P$_"} } $p_start..($p_start+2) ],
        );

        # Fake a ShipmentReady from IWS
        $framework->flow_wms__send_shipment_ready(
            shipment_id => $shipments{"S$sid"}->{'shipment_id'},
            container => {
                $totes{"T" . $sid} => [ map { $_->{'sku'} } @{ $shipments{"S$sid"}->{product_objects} } ]
            },
        );
    }
}

test_prefix("Tote 1");

# Let's scan T1
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $totes{'T1'} );

# Check we're on the Check Shipment Page
$framework->assert_location(qr!^/Fulfilment/Packing/CheckShipment!);

# Open a new tab to do cancel the order
$framework
    ->open_tab("Customer Care")
    ->flow_mech__customercare__cancel_order( $shipments{'S1'}->{'order_object'}->id )
    ->flow_mech__customercare__cancel_order_submit
    ->flow_mech__customercare__cancel_order_email_submit
    ->close_tab();

# Try and submit QC details
$framework->catch_error(
    qr/shipment has changed/,
    "Check user is told shipment is changed",
    flow_mech__fulfilment__packing_checkshipment_submit => ()
);

# Check we're on the empty tote page
eval { $framework->assert_location(qr!^/Fulfilment/Packing/EmptyTote!); };
fail "That assertion failed" if $@;

test_prefix("Tote 2");

# OK, on to Tote 2. We're on the wrong page, so we're going to cheat and go to
# the packing page first
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $totes{'T2'} );

# Check we're on the Check Shipment Page
$framework->assert_location(qr!^/Fulfilment/Packing/CheckShipment!);

# Open a new tab and do a size exchange
$framework
    ->open_tab("Customer Care")
    ->flow_mech__customercare__orderview( $shipments{'S2'}->{'order_object'}->id )
    ->flow_mech__customercare__size_change()
    ->flow_mech__customercare__size_change_submit( [ sku('P4') => sku('P7') ] )
    ->flow_mech__customercare__size_change_email_submit
    ->close_tab();

# Try and submit QC details
$framework->catch_error(
    qr/shipment has changed/,
    "Check user is told shipment is changed",
    flow_mech__fulfilment__packing_checkshipment_submit => ()
);

# We should have been put back on PIPE page with the two non-cancelled items.
$framework->assert_location(qr!^/Fulfilment/Packing/PlaceInPEtote!);
$framework
    ->test_mech__pipe_page__test_items(
        handled => [],
        pending => [ map {;{
            SKU => sku($_),
            QC => 'Ok',
            Container => $totes{'T2'}
        }} ('P5', 'P6') ]
    );

# As a nice endnote, let's try and type in a cancelled shipment, and check it
# doesn't take you anywhere.
test_prefix("Scan a cancelled shipment");
$framework->flow_mech__fulfilment__packing;
$framework->catch_error(
    qr/That shipment has been cancelled, please try another/,
    "Scanning a cancelled shipment doesn't work",
    flow_mech__fulfilment__packing_submit => ( $shipments{'S1'}->{'shipment_id'} )
);
eval { $framework->assert_location(qr!^/Fulfilment/Packing($|\?)!); };
fail "That assertion failed" if $@;

done_testing;

sub sku {
    my $pid = shift();
    return $products{$pid}->{'sku'};
}

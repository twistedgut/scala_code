#!/usr/bin/env perl

=head1 NAME

multi_shipment_tote.t - Packing Exceptions for multi-tote shipments

=head1 DESCRIPTION

PIPE = Put In Packing Exception

Packing Exceptions, Chapter 2.

It was a dark and stormy night, and we're going to test:

    - An item cancelled from an order if orphaned
    - An item from a cancelled order is orphaned
    - An item from a shipment on hold needs to be PIPE'd
    - An item that fails QC needs to be PIPE'd

#TAGS fulfilment packing packingexception iws prl loops whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::RunCondition
    export => [qw( $iws_rollout_phase $prl_rollout_phase )];

use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use XTracker::Config::Local qw(config_var);


use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data qw/qc_fail_string/;
use Test::XT::Flow;
use Test::XT::Data::Container;

test_prefix('Setup');

# Start-up gubbins here.
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::AppMessages',
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::WMS',
        'Test::XT::Flow::PRL',

    ],
);

$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

# We're going to start off by creating five shipments, each containing one item.
# We'll call them S1-S5. The item in each, we'll call P1-5. So S1 contains P1,
# S2 contains P2, etc.

my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 6 });
my %products = map {; "P$_" => shift( @$pids ) } 1..(scalar @$pids);

# We're going to make sure that P2 contains more than one variant, as we're
# going to cancel it by swapping it. We'll put the other variant in P6.
my ($new_channel, $variants) =
    Test::XTracker::Data->grab_multi_variant_product({
        channel => $channel,
        ensure_stock => 1
    });
( $products{'P2'}, $products{'P7'} ) = @$variants;


# Pack S1-S4 in to T1, and S5 in to T2. We're going to throw an extra item (P6)
# in T1 too, but as we have no visibility of that in XTracker, we don't actually
# create it programatically. T5 is our Pipe-O tote

my %totes;
my $count;
for my $tote_id ( Test::XT::Data::Container->get_unique_ids( { how_many => 5 } )) {
    $totes{"T" . ++$count} = $tote_id;
}

my $method_name = ($iws_rollout_phase || $prl_rollout_phase) ?
    'flow_db__fulfilment__create_order_selected' :
    'flow_db__fulfilment__create_order';


my %shipments;
for my $s ( 1..5 ) {
    $shipments{"S$s"} = $framework->$method_name(
        channel  => $channel,
        products => [ $products{"P$s"} ],
    );
}

foreach (
    (map { [$totes{'T1'}, $_] } ('S1' .. 'S4')),
    [$totes{'T2'}, 'S5']
) {
    my $tote_id  = $_->[0];
    my $shipment = $_->[1];

    test_prefix('Setup - Picking ' . $shipment);
    note "Picking $shipment ".$shipments{$shipment}->{'shipment_id'};

    if ( $iws_rollout_phase ) {
        # Fake a ShipmentReady from IWS
        $framework->flow_wms__send_shipment_ready(
            shipment_id => $shipments{$shipment}->{'shipment_id'},
            container => {
                $tote_id => [ map { $_->{'sku'} } @{ $shipments{$shipment}->{product_objects} } ]
            },
         );
    } elsif ( $prl_rollout_phase ) {
        $framework->flow_msg__prl__pick_shipment(
            shipment_id => $shipments{$shipment}->{'shipment_id'},
            container => {
                $tote_id => [ map { $_->{'sku'} } @{ $shipments{$shipment}->{'product_objects'} } ]
            },
        );
        $framework->flow_msg__prl__induct_shipment(
            shipment_id => $shipments{$shipment}->{'shipment_id'},
        );
    } else {
        my $shipment_id = $shipments{$shipment}->{'shipment_id'};

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
    }
}


# Cancel S1
test_prefix('Cancelling Shipment 1');
$framework
    ->flow_mech__customercare__cancel_order( $shipments{'S1'}->{'order_object'}->id )
    ->flow_mech__customercare__cancel_order_submit
    ->flow_mech__customercare__cancel_order_email_submit;

is( $framework->mech->as_data->{'meta_data'}->{'Order Details'}->{'Order Status'},
    'Cancelled', 'Order has been cancelled');

# Cancel P2
test_prefix('Cancelling Product 2');
note "Cancelling Product 2 from Shipment 2";
$framework
    ->flow_mech__customercare__orderview( $shipments{'S2'}->{'order_object'}->id )
    ->flow_mech__customercare__size_change()
    ->flow_mech__customercare__size_change_submit(
        [ sku('P2'), sku('P7') ]
    )->flow_mech__customercare__size_change_email_submit;

# Place S3 on hold
test_prefix('Shipment 3 on hold');
note "Placing Shipment 3 on hold";
$framework
    ->flow_mech__customercare__orderview( $shipments{'S3'}->{'order_object'}->id )
    ->flow_mech__customercare__hold_shipment()
    ->flow_mech__customercare__hold_shipment_submit();

is( $framework->mech->as_data->{'meta_data'}->{'Shipment Details'}->{'Status'},
    'Hold', 'Shipment 3 has been placed on hold' );

# SO:
# S1 is cancelled
# S2's only item is cancelled
# S3 is on hold
# S4 is fine

test_prefix('T1 Tests');

$framework->mech__fulfilment__set_packing_station( $channel->id );

# Scan T1. S1 and S2 should be ignored, as one is cancelled, and the other
# contains no packable items in the tote. We should be asked to scan an item.
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $totes{'T1'} );

# We are going to scan P1, and we want to be told to find another item to scan
# instead - P1 is orphaned because its shipment is cancelled.
# Then we scan P2, and want to be told to scan something else instead. P2 is
# orphaned because it's a cancelled item from a shipment.
$framework->catch_error(
    qr/That item doesn't seem to belong to any shipment. Please put the item back and scan another item/,
    "$_ scanned, correct error message received",
    flow_mech__fulfilment__packing_scan_item => ( sku($_) )
) for ( 'P1', 'P2' );

# Now we scan P3. This takes us to the PIPE page, as the shipment it links to,
# P3, is on hold.
$framework->catch_error(
    qr/The shipment \d+ is on hold/,
    "P3 scanned, correct error message received",
    flow_mech__fulfilment__packing_scan_item => ( sku('P3') )
);

# Check that "Items to be put in PE tote" table has only our item, and that
# "Items already in PE tote" does not.
$framework->test_mech__pipe_page__test_items(
    handled => [],
    pending => [{ SKU => sku('P3'), QC => 'Ok', Container => $totes{'T1'} }]
);

# On the pipe page. Try and trick the system by scanning the SKU for a couple
# of different items, and the tote, and check that each is rejected
for (
    ["P1 - an item from a cancelled shipment", sku('P1') ],
    ["P4 - a valid item from a different shipment in this tote", sku('P4') ],
    ["P5 - a random item that we'll later check is orphaned", sku('P6') ],
    ["The tote barcode", $totes{'T1'}]
) {
    my ( $bad_type, $bad_id ) = @$_;
    note "Trying to fool the PIPE page by inputting: $bad_type";
    $framework->catch_error(
        qr/The sku entered \(.+\)/,
        "Error message received scanning: $bad_type",
        flow_mech__fulfilment__packing_placeinpetote_scan_item => ( $bad_id )
    );
}

# Scan P3
$framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( sku('P3') );
$framework->mech->content_like( qr!Enter Container/Tote id!, "Prompted to scan tote id" );

# Try and scan the tote it's already in
$framework->catch_error(
    qr/You must use a new tote/,
    "Correct error message received trying to use originating tote as a PE tote",
    flow_mech__fulfilment__packing_placeinpetote_scan_item => ( $totes{'T1'} )
);

# Try and scan it in to another tote that's got something in it...
$framework->catch_error(
    qr/The tote you scanned contain items from different shipments/,
    "Correct error message received trying to use an already-used tote as a PE tote",
    flow_mech__fulfilment__packing_placeinpetote_scan_item => ( $totes{'T2'} )
);

# Fine, scan it to T3
$framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $totes{'T3'} );

# Check item has moved to handled, from pending
$framework->test_mech__pipe_page__test_items(
    pending => [],
    handled => [ { SKU => sku('P3'), QC => 'Ok', Container => $totes{'T3'} } ]
);

# Check we're prompted to get rid of the tote
$framework->test_mech__app_info_message__like(
    qr/Please send the tote\(s\) to the packing exception desk/,
    "We are prompted to get rid of the tote"
);
$framework->flow_mech__fulfilment__packing_placeinpetote_mark_complete();

# We should now have S4 magically selected, and be being asked to QC the items
# in it. We're going to QC fail P4, and check we get taken to the PIPE page.
my $fail_message = "This item is missing gaudy baubles";

$framework->catch_error(
    qr/Please scan item\(s\) from shipment \d+ into new tote\(s\)/,
    "User prompted to put failed item's shipment in PIPE",
    flow_mech__fulfilment__packing_checkshipment_submit =>
        ( fail => { sku('P4') => $fail_message } )
);

my $operator_name = $framework->mech->app_operator_name();

# Scan P4 to a packing exception tote.
$framework
    ->test_mech__pipe_page__test_items(
        handled => [],
        pending => [{
            SKU => sku('P4'),
            QC => qc_fail_string($fail_message, $operator_name),
            Container => $totes{'T1'}
        }]
    )->flow_mech__fulfilment__packing_placeinpetote_scan_item( sku('P4') )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $totes{'T4'} )
    ->test_mech__pipe_page__test_items(
        pending => [],
        handled => [{
            SKU => sku('P4'),
            QC => qc_fail_string($fail_message, $operator_name),
            Container => $totes{'T4'}
        }]
    )->flow_mech__fulfilment__packing_placeinpetote_mark_complete();

# We should now be asked to confirm the tote is empty. As we have P1, P2, and
# P5 in it, we say no, and should be taken to PIPE-O
$framework->assert_location(qr!^/Fulfilment/Packing/EmptyTote!);
$framework->flow_mech__fulfilment__packing_emptytote_submit('no');

# Scan the items in correctly, and check they're shown
for ( 'P1', 'P2', 'P7' ) {
    $framework
        ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item(sku($_))
        ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($totes{'T5'})
}

# Say we're complete
$framework->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete;
$framework->assert_location(qr!^/Fulfilment/Packing/EmptyTote!);

done_testing;

sub sku {
    my $pid = shift();
    return $products{$pid}->{'sku'};
}

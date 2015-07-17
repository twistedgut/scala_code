#!/usr/bin/env perl

=head1 NAME

missing_items_from_pipe_to_packing_exception.t - Shipment changes during PIPE

=head1 DESCRIPTION

PIPE = Put In Packing Exception

Test CheckShipmentException page in the PackingException bench

Load up a shipment with 5 items. Pick, and place it on hold. Start to pack,
which takes us to PIPE page. While on the PIPE page, cancel an item.

We're pressing the "This item is missing" button and asserting that:

    a) the shipment_item_id gets placed in the right status
    b) the right message is sent

For that, We need to create a shipment which has some items that failed QC
and went L<MIA|http://www.imdb.com/title/tt0087727> right afterwards so that
they can be marked as missing whilst being put into a PIPE tote and sent to
the packing exception bench where we can flag them as well as another one
as missing.

=head2 Addendum

From a five items shipment we'll at this point be in a state where we the
shipment at PackingException and we have 2 of the original items in a tote
and 3 of them missing which we already marked as missing.

We're now going to cancel the whole shipment and exercise dealing with the
cancelled pending items and that tote as well.

In between this we're also going to play with the status of the shipment while
we are actively about to cancel something to see if our shipment_state_signature
logic kicks in.

#TAGS fulfilment packing packingexception iws whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::RunCondition export => qw( $iws_rollout_phase );


use Test::XTracker::Data qw/qc_fail_string/;
use Test::XT::Flow;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;

use Carp::Always;

# Start-up gubbins here. Test plan follows later in the code...
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::AppMessages',
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Flow::WMS',
    ],
);

$framework->clear_sticky_pages;
$framework->login_with_permissions({
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

# set up an amq read dir
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

my $schema = Test::XTracker::Data->get_schema;

# Russle up 5 products
my $product_count = 5;
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => $product_count });

# create a picked order with those pids
my $order_data = $framework->flow_db__fulfilment__create_order_picked( channel  => $channel, products => $pids, );

# set some vars
my %products = map {; "P$_" => shift( @$pids ) } 1..(scalar @$pids);
my $shipment_id = $order_data->{'shipment_id'};
my $order_id = $order_data->{'order_object'}->id;


# Pack the items
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $shipment_id );

# Fail items
my @items_to_fail = @{$framework->mech->as_data()->{shipment_items}};

# Let's QC fail a couple of items whilst packing
$framework->errors_are_fatal(0);
$framework
    ->flow_mech__fulfilment__packing_checkshipment_submit(
        missing => [
            map { $items_to_fail[$_]->{'shipment_item_id'} } 0 .. 1
        ]
    );
$framework->errors_are_fatal(1);

# Finish packing it on the PIPE page
my ($packing_tote_id, $faulty_container) = Test::XT::Data::Container->get_unique_ids( { how_many => 2 } );
for my $pid ( map {"P$_"} 1..5 ) {
    # Skip the two pids we're saying are missing
    next if $items_to_fail[0]->{'SKU'} eq $products{$pid}->{'sku'};
    next if $items_to_fail[1]->{'SKU'} eq $products{$pid}->{'sku'};
    $framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $products{$pid}->{'sku'} );
    $framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $packing_tote_id );
}

$framework->flow_mech__fulfilment__packing_placeinpetote_mark_complete();

# at this point we expect 3 messages :
#   a shipment_request
#   a shipment received
#   a shipment reject
$xt_to_wms->expect_messages({
    messages => [
        {   '@type'   => 'shipment_received',
        },
        {   '@type'   => 'shipment_reject',
        }
    ]
});

# Let's now go and check the PackingException test,
# let's confirm that one is missing, say one of them is there but faulty
# and let's also say there's somthing else missing as well.
# 3 items will be missing in total

$framework
    ->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $shipment_id )
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_missing( $items_to_fail[0]->{'shipment_item_id'} )
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_faulty( $items_to_fail[1]->{'shipment_item_id'} )
    ->flow_mech__fulfilment__packing_scanoutpeitem_sku( $items_to_fail[1]->{SKU} )
    ->flow_mech__fulfilment__packing_scanoutpeitem_tote( $faulty_container )
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_missing( $items_to_fail[2]->{'shipment_item_id'} );

# Check that the missing items are in NEW state
my $items_ready_to_be_picked_count = $schema->resultset('Public::ShipmentItem')
    ->search({
        shipment_id => $shipment_id,
        shipment_item_status_id => $iws_rollout_phase == 0 ? $SHIPMENT_ITEM_STATUS__NEW : $SHIPMENT_ITEM_STATUS__SELECTED,
    })->count;

is($items_ready_to_be_picked_count,3,"Right number of items in ". ($iws_rollout_phase == 0 ? "NEW" : "SELECTED" )." state");

#if ($iws_rollout_phase > 0) {
    my @messages;
    for my $index (0..2) {
        push @messages,{
            '@type'   => 'item_moved',
            'details' => { 'items' => [{ sku => $items_to_fail[$index]->{'SKU'}}] }
        }
    }

    $xt_to_wms->expect_messages({
        messages => \@messages
    });
#}

# Get me an Evil tote to play with...
my ($cancelled_items_after_cancelled_order_tote) =
    Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );

# Reload the PackingException page
# We should have two items in need of being removed from the current container into a "Putaway" container

# Let's load the page which has the faulty and missing buttons
$framework
    ->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $shipment_id );
$framework->assert_location(qr!^/Fulfilment/Packing/CheckShipmentException!);

# Let's tweak the shipment emulating a shipment change
# Don't think we need to care about what we're updating...
_tweak_shipment_qc_message($shipment_id,"foo");

my $item=$schema->resultset('Public::ShipmentItem')->find($items_to_fail[3]->{'shipment_item_id'});

my $orig_container = $item->container_id;

# Let's go back to that page and still try to mark the now cancelled item into a faulty one
# Make sure our shipment_state_signature kicks in.
$framework->catch_error(
        qr{Shipment $shipment_id has changed since you started working on it},
        'Supervisor shown message about shipment change in between actions',
        flow_mech__fulfilment__packingexception_shipment_item_mark_missing => $items_to_fail[3]->{'shipment_item_id'});

$item->discard_changes;
is($item->container_id,$orig_container,'action did not have effect');

# Let's do the same a deeper level
$framework
    ->assert_location(qr!^/Fulfilment/Packing/CheckShipmentException!)
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_faulty( $items_to_fail[3]->{'shipment_item_id'} );

_tweak_shipment_qc_message($shipment_id,"bar");

# Make sure our shipment_state_signature kicks in.
$framework
    ->catch_error(
        qr{Shipment $shipment_id has changed since you started working on it},
        'Supervisor shown message about shipment change in between actions',
        flow_mech__fulfilment__packing_scanoutpeitem_sku => $items_to_fail[3]->{'SKU'} );

$item->discard_changes;
is($item->container_id,$orig_container,'action did not have effect');

# We're back at the Check Shipment Exception page
# Let's cancel the whole shipment
$framework
    ->open_tab("Customer Care")
    ->flow_mech__customercare__cancel_order( $order_id )
    ->flow_mech__customercare__cancel_order_submit
    ->flow_mech__customercare__cancel_order_email_submit
    ->close_tab();

# Ok, sweet, let's just cancel the items then and go home
$framework
    ->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $shipment_id )
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_putaway( $items_to_fail[3]->{'shipment_item_id'} )
    ->flow_mech__fulfilment__packing_scanoutpeitem_sku( $items_to_fail[3]->{'SKU'} )
    ->task__fulfilment__packing_scanoutpeitem_to_putaway(
        $cancelled_items_after_cancelled_order_tote,
        $items_to_fail[3]->{'SKU'},
    )
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_putaway( $items_to_fail[4]->{'shipment_item_id'} )
    ->flow_mech__fulfilment__packing_scanoutpeitem_sku( $items_to_fail[4]->{'SKU'} )
    ->task__fulfilment__packing_scanoutpeitem_to_putaway(
        $cancelled_items_after_cancelled_order_tote,
        $items_to_fail[4]->{'SKU'},
    );

# Make sure we're back at the PackingException page and are providing a nice message to the user.
$framework->assert_location(qr!^/Fulfilment/PackingException!);
like($framework->mech->app_status_message,
     qr{Cancelled shipment $shipment_id has now been dealt with},
     'Supervisor shown message about cancelled shipment after last item ws scanned out of the tote');

if ($iws_rollout_phase ) {
    $xt_to_wms->expect_messages({
        messages => [
            {   '@type'   => 'shipment_cancel',
                'details' => { shipment_id => "s-$shipment_id" }
            },
            {
                '@type'   => 'item_moved',
                'details' => { 'shipment_id' => "s-$shipment_id",
                               'items' => [{sku => $items_to_fail[3]->{'SKU'},
                                            quantity => 1,}],
                           },
            },
            {
                '@type'   => 'item_moved',
                'details' => { 'shipment_id' => "s-$shipment_id",
                               'items' => [{sku => $items_to_fail[4]->{'SKU'},
                                            quantity => 1,}],
                           },
            },
        ]
    });
}
# We are adding this call as RAVNI consumes but ignore shipment_cancel and
# item_moved messages (apologies for the rubbish bulldozer approach)
else {
    $xt_to_wms->new_files;
}

done_testing();




sub _tweak_shipment_qc_message {
    my ($shipment_id,$msg) = @_;

    $schema->resultset('Public::ShipmentItem')->search(
        {
            shipment_id => $shipment_id },
        {
            rows =>1 })->single
        ->update({ qc_failure_reason => $msg});

}

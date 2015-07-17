#!/usr/bin/env perl

=head1 NAME

no_problems.t - Test the Packing Exception page's ability to handle things sent to it in error

=head1 DESCRIPTION

Setup as follows
    - create an order with multiple items/vouchers
    - packing QC fail at least one item for being missing

Then do some tests...

Ensure that supervisor can send it back to packer and tote info is correct.

#TAGS fulfilment packing packingexception iws whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition
    dc => 'DC1', export => qw( $iws_rollout_phase );

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;
use Carp::Always;

# Start-up gubbins here. Test plan follows later in the code...
test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Data::Location',
    ],
);
$framework->clear_sticky_pages;
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

# create and pick the order
test_prefix("Setup: order shipment");
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 3 });
my $order_data = $framework->flow_db__fulfilment__create_order_picked( channel  => $channel, products => $pids, );
note "shipment $order_data->{'shipment_id'} created";

# create another order in the picked state to create errors against later
my ($picked_channel,$picked_pids) = Test::XTracker::Data->grab_products({ how_many => 3 });
my $picked_order_data = $framework->flow_db__fulfilment__create_order_picked( channel  => $picked_channel, products => $picked_pids, );


# Pack shipment
test_prefix("Setup: fail pack QC ");
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $order_data->{tote_id} );

my $items = $framework->mech->as_data()->{shipment_items};
my ($pe_tote) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );

# fail packing QC
$framework->catch_error(
    qr/Please scan item\(s\) from shipment \d+ into new tote\(s\)/,
    "User prompted to put failed item's shipment in PIPE",
    flow_mech__fulfilment__packing_checkshipment_submit =>
        (
            missing => [ $items->[0]->{SKU} ],
            fail => { $items->[1]->{SKU} => 'Item is dangerously radioactive'}
        )
    )

# should take you to PIPE page
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $items->[1]->{SKU} )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $pe_tote )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $items->[2]->{SKU} )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $pe_tote );


note "real tests start here.";
test_prefix("Packing Exception page");
$framework->clear_sticky_pages;
$framework->flow_mech__fulfilment__packingexception;
$framework->flow_mech__fulfilment__packingexception_submit($order_data->{'shipment_id'});

# mark missing item as OK
my $xt_to_wms=Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

my $page_data = $framework->mech->as_data();
my $page_item = [grep { $_->{SKU} eq $items->[0]->{SKU} } @{$page_data->{shipment_items}}]->[0];
like($page_item->{QC}, qr/Marked as missing/, 'Shipment item is marked as QC fail');
is($page_item->{Container}, '', 'Item not in a container yet');
$framework->flow_mech__fulfilment__packingexception_shipment_item_mark_ok( $items->[0]->{shipment_item_id} )
    # need to scan found item into tote
    ->catch_error(
        qr/The SKU you entered does not match the target item's SKU/,
        "Sku was not the sku we expected",
        flow_mech__fulfilment__packingexception__scan_item_into_tote => ($items->[1]->{SKU})
    )
    ->flow_mech__fulfilment__packingexception__scan_item_into_tote( $items->[0]->{SKU} )
    ->catch_error(
        qr/Invalid container id \(it should begin with 'M', 'T', or 'PH'\)/,
        "Invalid container id",
        flow_mech__fulfilment__packingexception__scan_item_into_tote => ('this isnt a tote id is it?')
    )
    ->catch_error(
        qr/This container is being used for Picked Items/,
        "Can't put found item into pick tote",
        flow_mech__fulfilment__packingexception__scan_item_into_tote => ($picked_order_data->{tote_id})
    )
    ->flow_mech__fulfilment__packingexception__scan_item_into_tote( $pe_tote )
    ->mech->has_feedback_success_ok(qr/Successfully placed back into Tote/);

$page_data = $framework->mech->as_data();
$page_item = [grep { $_->{SKU} eq $items->[0]->{SKU} } @{$page_data->{shipment_items}}]->[0];
is($page_item->{QC}, 'Ok', 'Shipment item is now marked as QC OK');
$xt_to_wms->expect_messages({
    messages => [{
        '@type'   => 'item_moved',
        'details' => { 'items'    => [{ sku => $items->[0]->{SKU},
                                       'quantity' => 1 }],
                       'from' => {'no' => 'where'},
                       'to'   => { container_id => $pe_tote,
                                   stock_status => 'main'}
                      }
    }]
});

# mark qc failed item as OK
$page_item = [grep { $_->{SKU} eq $items->[1]->{SKU} } @{$page_data->{shipment_items}}]->[0];
like($page_item->{QC}, qr/Item is dangerously radioactive/, 'Shipment item is marked as QA fail');

$framework->flow_mech__fulfilment__packingexception_shipment_item_mark_ok( $items->[1]->{shipment_item_id} )
    ->mech->has_feedback_success_ok(qr/shipment item $items->[1]->{SKU} has been marked as non-faulty/);

$page_data = $framework->mech->as_data();
$page_item = [grep { $_->{SKU} eq $items->[1]->{SKU} } @{$page_data->{shipment_items}}]->[0];
is($page_item->{QC}, 'Ok', 'Shipment item is now marked as QC OK');



done_testing;

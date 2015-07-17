#!/usr/bin/env perl

=head1 NAME

fail_extra_shipment_items.t - Test the ability to QC fail and fix a shipment due to missing documents at packing

=head1 DESCRIPTION

Test process:

    - create an order - Mr P, NOT premier (with gift message?) - picked
    - ensure that expected print docs appear on Packing screen - including identifying text
    - make shipment premier
    - check that they're forced to re-QA the shipment as there's a new print doc requirement
    - ensure that expected print docs appear on Packing screen - including identifying text
    - ensure that packer can fail a shipment based upon missing/faulty print docs
    - ensure packer is redirected to PIPE page
    - ensure shipment appears on PE page. select it.
    - check that the extra items appear on the page
    - check we don't have the 'all fixed' button yet
    - fix the items
    - check we do have the 'all fixed' button
    - press 'all fixed' button
    - check it's in the commissioner

#TAGS fulfilment packing packingexception iws whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;

use Test::XTracker::RunCondition(
    iws_phase => '2',
    export    => qw( $iws_rollout_phase ),
);


use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status :shipment_type);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;
use Carp::Always;

# Start-up gubbins here. Test plan follows later in the code...
test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
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
        'Fulfilment/Picking',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

# create and pick the order
test_prefix("Setup: order shipment");
my $number_of_products = 5;
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => $number_of_products, channel => 'mrp' });
my $order_data = $framework->flow_db__fulfilment__create_order_picked( channel  => $channel, products => $pids, );
my $shipment = $order_data->{shipment_object};
# ensure MrP sticker value
$shipment->order->update({sticker => 'Mr Man'});
note "shipment $order_data->{'shipment_id'} created";

# Pack shipment
test_prefix("Setup: fail pack QC ");
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $order_data->{tote_id} );

my $items = $framework->mech->as_data();

is (@{$items->{shipment_extra_items}}, 1, "we currently have 1 shipment extra item1 for this shipment");
is ($items->{shipment_extra_items}->[0]->{'Item type'}, 'MrP Sticker', "Other is MrP sticker");
is ($items->{shipment_extra_items}->[0]->{'Description / Content'}, 'Mr Man (quantity: '.$number_of_products.')', "Sticker content and quantity displayed OK");
note("make it premier");
$shipment->update({ shipment_type_id => $SHIPMENT_TYPE__PREMIER, });
$shipment->apply_SLAs;

# fail packing QC
$framework->catch_error(
    qr/This shipment has changed/,
    "User has to re-QA as print docs requirement has changed",
    flow_mech__fulfilment__packing_checkshipment_submit =>
        ( fail => { $items->{shipment_extra_items}->[0]->{id} => "Why oh why oh why. Nobody knows." } )
    );

# grab page contents again
$items = $framework->mech->as_data();

is (@{$items->{shipment_extra_items}}, 2, "we have 2 shipment extra items for this shipment");
is ($items->{shipment_extra_items}->[0]->{'Item type'}, 'Address Card', "One is an address card");
like ($items->{shipment_extra_items}->[0]->{'Description / Content'}, qr/London/, "Address label content displayed OK");
is ($items->{shipment_extra_items}->[1]->{'Item type'}, 'MrP Sticker', "Other is MrP sticker");
is ($items->{shipment_extra_items}->[1]->{'Description / Content'}, 'Mr Man (quantity: '.$number_of_products.')', "Sticker content and quantity displayed OK");

# fail packing QC
$framework->catch_error(
    qr/Please scan item\(s\) from shipment \d+ into new tote\(s\)/,
    "User prompted to put failed item's shipment in PIPE",
    flow_mech__fulfilment__packing_checkshipment_submit => (
        fail    => { $items->{shipment_extra_items}->[0]->{id} => "Why oh why oh why. Nobody knows." },
        missing => [ $items->{shipment_extra_items}->[1]->{id} ]
    )
);


# should take you to PIPE page
test_prefix("PIPE page");
my ($pe_tote) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );
$framework
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $items->{shipment_items}->[0]->{SKU} )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $pe_tote );

$framework->clear_sticky_pages;
test_prefix("Packing Exception page");
$framework->flow_mech__fulfilment__packingexception;
$framework->flow_mech__fulfilment__packingexception_submit($pe_tote);

my $pe_items = $framework->mech->as_data;
is(@{$pe_items->{shipment_extra_items}}, 2, "Right number of extra items shown on PE page");
is(  $pe_items->{shipment_extra_items}->[0]->{'Item type'}, 'Address Card', "One is an address card");
like($pe_items->{shipment_extra_items}->[0]->{'QC'}, qr/Why oh why oh why/, "Address card QC fail displayed OK");
is(  $pe_items->{shipment_extra_items}->[1]->{'Item type'}, 'MrP Sticker', "Other is MrP sticker");
is ($items->{shipment_extra_items}->[1]->{'Description / Content'}, 'Mr Man (quantity: '.$number_of_products.')', "Sticker content and quantity displayed OK");
like($pe_items->{shipment_extra_items}->[1]->{'QC'}, qr/Marked as missing/, "Sticker qc fail displayed OK");
$framework->mech->content_lacks('All items have been checked', 'Shipment not fixed yet');

# fix one item
$framework->flow_mech__fulfilment__packingexception_shipment_extra_item_mark_ok( $pe_items->{shipment_extra_items}->[0]->{id} )
    ->mech->has_feedback_success_ok(qr/Shipment extra item '$pe_items->{shipment_extra_items}->[0]->{'Item type'}' marked as fixed/);
$framework->mech->content_lacks('All items have been checked', 'Shipment not fixed yet');

# fix other item
$framework->flow_mech__fulfilment__packingexception_shipment_extra_item_mark_ok( $pe_items->{shipment_extra_items}->[1]->{id} )
    ->mech->has_feedback_success_ok(qr/Shipment extra item '$pe_items->{shipment_extra_items}->[1]->{'Item type'}' marked as fixed/);
$framework->mech->content_contains('All items have been checked', 'Shipment now fixed');

# say we're done
$framework->flow_mech__fulfilment__packing_checkshipmentexception_submit()
    # TODO: if this test is enabled for PRL, this message will change,
    # see DCA-1667
    ->mech->has_feedback_success_ok(qr/Sent shipment $order_data->{'shipment_id'} to the commissioner ready to be sent to packer/);
$framework->flow_mech__fulfilment__packingexception_submit($pe_tote)
    ->mech->has_feedback_success_ok(qr/Shipment $order_data->{'shipment_id'} is not in packing exception status/);

done_testing();

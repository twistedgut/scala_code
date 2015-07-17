#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

faulty_pigeonhole_item.t - Pack multiple items from the same pigeon hole, one is
faulty(IWS only)

=head1 DESCRIPTION

Note that this test is an adaptation of an existing test
(t/30-functional/whm/fulfilment/fulfilment_pigeonhole_multiple.t).

Also it's worth pointing out that this test exists because I don't believe we
have any tests that check for multiple items in a pigeonhole behaviour in DC1 -
we used to have a one-item only policy, but this changed as of the GOH code.

Here's what happens:

=over

=item Create a selected shipment with two items of the same SKU

=item Send a shipment ready, with both items in the same pigeonhole

=item Begin packing, fail one item and check we get a message telling the
packer to return the item to its original pigeonhole and take any paperwork to
the packing exception desk

=item Check we're redirected to the PlaceInPEtote page

=item Scan both items and place them in the same pigeonhole

=item Press complete and check we send a shipment reject

=item Go to the packing exception page, and insert the shipment number

=item It actually turns out the item's ok, so mark it as such

=item Confirm and chceck we send a shipment wms pause message

=item Pack both items and check we send a shipment packed message on completion

=back

#TAGS fulfilment packing packingexception iws http duplication whm

=cut

use FindBin::libs;

use Test::XTracker::RunCondition iws_phase => 'iws';

use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level );
use Test::XTracker::Data;
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
    ]}
});

my $product = (Test::XTracker::Data->grab_products({force_create => 1}))[1][0]{product};
my $shipment = $framework->flow_db__fulfilment__create_order_selected(
    products => [($product) x 2],
)->{shipment_object};
# Due to us passing fucking products instead of variants when we create our
# orders/shipments, we need to obtain our variant here as on a multi-size
# product it's not clear which variant is used to create the
# shipment</minirant>
my $variant = $shipment->shipment_items->slice(0,0)->single->variant;

# I don't know why this specific prefix is generated, borrowed identifier (and
# +1ed) from another test
my ($p_container_id) = Test::XT::Data::Container->get_unique_ids({ prefix => 'PH7358' });

$framework->flow_wms__send_shipment_ready(
    shipment_id => $shipment->id,
    container => { $p_container_id => [ ($variant->sku) x 2 ] },
);

# Pack the items
$framework->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $p_container_id );

my $item_to_fail_id = $framework->mech->as_data->{shipment_items}[0]{shipment_item_id};

# Fail QC
$framework->catch_error(
    'Please return pigeon hole items to their original pigeon holes and take any labels and paperwork to the packing exception desk',
    'packer asked to send shipment to exception desk',
    'flow_mech__fulfilment__packing_checkshipment_submit' => (
        fail => { $item_to_fail_id => 'fail for any reason', }
    )
);
is($framework->mech->uri->path, '/Fulfilment/Packing/PlaceInPEtote',
   'pack QC fail requires putting items into another tote');

# We put both the faulty and ok items into the pigeonhole
$framework->flow_mech__fulfilment__packing_placeinpetote_scan_item($variant->sku)
    ->flow_mech__fulfilment__packing_placeinpetote_pigeonhole_confirm($p_container_id)
        for 1..2;
{
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
$framework->flow_mech__fulfilment__packing_placeinpetote_mark_complete;
$xt_to_wms->expect_messages({ messages => [{ type => 'shipment_reject' }] });
}

# At packing exception we just say the shipment is actually ok, so check we
# unpause the shipment
$framework->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $shipment->id )
    ->flow_mech__fulfilment__packing_checkshipmentexception_ok_sku( $item_to_fail_id );
{
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
$framework->flow_mech__fulfilment__packing_checkshipmentexception_submit;
$xt_to_wms->expect_messages({ messages => [{
    type   => 'shipment_wms_pause',
    details => {
        shipment_id => 's-'.$shipment->id,
        pause       => JSON::XS::false
    },
}]});
}

# We're now able to carry on packing - let's just sure we can reach completion
$framework->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $p_container_id );

$framework->flow_mech__fulfilment__packing_checkshipment_submit;

$framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $variant->sku )
    for 1..2;

$framework->flow_mech__fulfilment__packing_packshipment_submit_boxes(
    channel_id => $shipment->get_channel->id
)->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789");

{
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
$framework->flow_mech__fulfilment__packing_packshipment_complete;

$xt_to_wms->expect_messages({ messages => [ {
    'type'   => 'shipment_packed',
    'details' => { shipment_id => 's-'.$shipment->id }
}]});
}

done_testing;

#!/usr/bin/env perl

=head1 NAME

prl_on__one_item_faulty_one_ok.t - Pack shipment with two items, one faulty, one ok (PRL on)

=head1 DESCRIPTION

Create shipment with two items that are marked as missing.

On packing 'check shipment' page, message should be:
    "The Packing Exception desk has been informed of this shipment".

We should be at 'confirm empty'.

On Packing exception page confirm one item to be OK and other faulty.

Verify correct confirmation message is shown:
    "Please go to the ... Commissioner ... to send the shipment XXXX to packing.

Check that shipment appears under correct section at Commissioner page.

Verify shipment is now in "Ready for Packing".

Created from Jira DCA-1084.

#TAGS fulfilment packing packingexception iws prl whm

=cut

use NAP::policy "tt";
use FindBin::libs;

use Test::XTracker::RunCondition(
    prl_phase => 'prl',
    export    => qw($iws_rollout_phase),
);

use Data::Dumper;
use Test::More;
use Test::Differences;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Config::Local qw( maybe_condition_config_var );
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Constants::FromDB qw(:authorisation_level);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;

note 'Setup';

my $xt_to_wms;
if ($iws_rollout_phase > 0) {
    $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
}

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::AppMessages',
        'Test::XT::Flow::Fulfilment',
    ],
);

$framework->clear_sticky_pages;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Commissioner',
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

note 'Get shipment with two items that are marked as missing';
my ($channel, $pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
});
my ($product_a, $product_b) = @$pids;
my ($sku_a, $sku_b) = ($product_a->{sku}, $product_b->{sku});
my ($tote, $pe_tote) = Test::XT::Data::Container->get_unique_ids({
    how_many => 2,
});

my $shipment = $framework->flow_db__fulfilment__create_order_picked(
    channel  => $channel,
    products => [ $product_a,  $product_b ],
    tote_id  => $tote
);

note 'Set items as missing';

$framework->mech__fulfilment__set_packing_station($channel->id);
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $tote );

my ($siid_a, $siid_b) = map {$_->{shipment_item_id}} @{ $framework->mech->as_data->{shipment_items} };

$framework
    ->flow_mech__fulfilment__packing_checkshipment_submit( missing => [ $sku_a, $sku_b ] )
    ->test_mech__app_info_message__is(
        'The Packing Exception desk has been informed of this shipment',
        "Packing Exception desk informed",
    );

if ($iws_rollout_phase > 0) {
    $xt_to_wms->expect_messages({
        messages => [
            { '@type' => 'shipment_received' },
            {
                '@type'   => 'shipment_reject',
                'details' => { containers => [] },
            },
        ]
    });
    undef $xt_to_wms;
}


note 'We should be at confirm empty';
$framework->assert_location(qr!/Fulfilment/Packing/EmptyTote!);

note 'On Packing exception page confirm one item to be OK and other - faulty';
$framework
    ->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $shipment->{shipment_id} );

my ($shipment_item_a, $shipment_item_b) =
        map { $framework->schema->resultset('Public::ShipmentItem')->find($_)}
        $siid_a, $siid_b;

$framework
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_faulty($shipment_item_a->id)
    ->flow_mech__fulfilment__packing_scanoutpeitem_tote($shipment_item_a->variant->sku)
    ->flow_mech__fulfilment__packing_scanoutpeitem_tote($pe_tote)
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_ok($shipment_item_b->id)
    ->flow_mech__fulfilment__packingexception__scan_item_into_tote($shipment_item_b->variant->sku)
    ->flow_mech__fulfilment__packingexception__scan_item_into_tote($tote)
    ->flow_mech__fulfilment__packing_checkshipmentexception_submit();


note 'Make sure correct confirmation message is shown';
my $expected_feedback_qr =
    qr/Please go to the.+?Commissioner.+? to send the shipment $shipment->{shipment_id} to packing/;
$framework->mech->has_feedback_success_ok(
    $expected_feedback_qr,
) or diag("HTML: " . $framework->mech->content);


note 'Check that shipment appears under correct section at Commissioner page';
$framework->flow_mech__fulfilment__commissioner;

# This should now be in "Ready for Packing"
my ($found_shipment) =
    grep {
        $_->{'Shipment Number'} eq $shipment->{shipment_id} &&
        $_->{'Container'}       eq $tote
    }
    @{$framework->mech->as_data->{'Ready for Packing'}};

ok( $found_shipment, "Shipment in Ready for Packing in Commissioner" )
    || die Dumper $framework->mech->as_data->{'Ready for Packing'};

done_testing;

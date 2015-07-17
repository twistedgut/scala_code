#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

single_item_refound.t - Find a missing item at packing exception

=head1 DESCRIPTION

Mark an item as missing, then at packing exception, mark it as found again.

#TAGS fulfilment packing packingexception iws whm

=cut

use Test::XTracker::RunCondition(
    export => qw( $iws_rollout_phase ),
);

use Data::Dumper;

use Test::Differences;
use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Config::Local qw( maybe_condition_config_var );
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Constants::FromDB qw(:authorisation_level);# :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;

test_prefix('Setup');

my $xt_to_wms;
if ( $iws_rollout_phase > 0 ) {
    $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms' );
}

# Start-up gubbins here. Test plan follows later in the code...
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

my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 1,
});
my $product = $pids->[0];
my $sku = $product->{'sku'};
my ($tote, $pe_tote) = Test::XT::Data::Container->get_unique_ids({
    how_many => 2,
});

my $shipment = $framework->flow_db__fulfilment__create_order_picked(
    channel  => $channel,
    products => [ $product ],
    tote_id  => $tote
);

test_prefix("Set item as missing");

$framework->mech__fulfilment__set_packing_station($channel->id);
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $tote );

my $siid = $framework->mech->as_data->{'shipment_items'}->[0]->{'shipment_item_id'};
note "Shipment item id: [$siid]";

# Fail P1
$framework
    ->flow_mech__fulfilment__packing_checkshipment_submit( missing => [ $sku ] )
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

# We should be at confirm empty
$framework->assert_location(qr!/Fulfilment/Packing/EmptyTote!);

test_prefix("Deal with it in PE");
$framework
    ->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $shipment->{shipment_id} );

# Mark the item as actually ok
$framework
    ->flow_mech__fulfilment__packingexception_shipment_item_mark_ok($siid)
    ->flow_mech__fulfilment__packingexception__scan_item_into_tote(  $sku )
    ->flow_mech__fulfilment__packingexception__scan_item_into_tote( $pe_tote )
    ->flow_mech__fulfilment__packing_checkshipmentexception_submit();

my $expected_feedback_qr
    = maybe_condition_config_var(
        "PackingException",
        "is_sent_to_packing_via_induction_point",
    )
    ? qr/Please go to the.+?Commissioner.+? to send the shipment $shipment->{shipment_id} to packing/
    : qr/Sent shipment $shipment->{shipment_id} to the commissioner ready to be sent to packer/;
$framework->mech->has_feedback_success_ok(
    $expected_feedback_qr,
) or diag("HTML: " . $framework->mech->content);
$framework
    ->flow_mech__fulfilment__commissioner;

# This should now be in "Ready for Packing"
my ($found_shipment) =
    grep {
        $_->{'Shipment Number'} eq $shipment->{shipment_id} &&
        $_->{'Container'}       eq $pe_tote
    }
    @{$framework->mech->as_data->{'Ready for Packing'}};

test_prefix("This is the important bit");
ok( $found_shipment, "Shipment in Ready for Packing in Commissioner" )
    || die Dumper $framework->mech->as_data->{'Ready for Packing'};

done_testing;


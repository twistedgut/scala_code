#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

fasttrack_multiple.t

=head1 DESCRIPTION

Create a delivery with multiple variants, run it through the fasttrack page,
but don't tick the fasttrack checkbox. Ensure it still works.

Test the following errors:
    * requesting a fasttrack with zero quantity.
    * both of two zero-quantity fasttracks should be present.

Ensure fasttracking only one of each SKU works.

Ensure the PreAdvice message sent to IWS contains the correct product IDs
and SKU IDs.

#TAGS goodsin qualitycontrol inventory fulfilment fasttrack iws whm

=cut

use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants::FromDB
    qw(
          :authorisation_level
          :stock_order_status
  );
use Test::Most;
use XTracker::Config::Local qw(config_var);
use Test::XTracker::Artifacts::RAVNI;
use Test::More::Prefix qw/test_prefix/;

use Test::XTracker::RunCondition export => qw( $iws_rollout_phase );

test_prefix('Setup');
my $schema = Test::XTracker::Data->get_schema;
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::Samples',
        'Test::XT::Data::Samples',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::StockControl',
        'Test::XT::Flow::PrintStation',
        'Test::XT::Feature::AppMessages',
    ],
);
$framework->mech->force_datalite(1);
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
my $channel = Test::XTracker::Data->get_local_channel;

test_prefix('Setup data');

my $po = Test::XTracker::Data->create_from_hash({
    channel_id      => $channel->id,
    placed_by       => 'Test User',
    stock_order     => [{
        status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
        product         => {
            size_scheme_id => 2,
            product_type_id => 6, # Dresses
            style_number    => 'Test Style',
            variant         => [{
                size_id => 10,
                stock_order_item    => {
                    quantity            => 10,
                },
            },{
                size_id => 11,
                stock_order_item    => {
                    quantity            => 10,
                },
            }],
            product_channel => [{
                channel_id      => $channel->id,
                live            => 0,
            }],
            product_attribute => {
                description     => 'Test Description',
            },
        },
    }],
});

my ($delivery) = Test::XTracker::Data->create_delivery_for_po($po->id, 'qc');
my ($sp) = Test::XTracker::Data->create_stock_process_for_delivery($delivery);

my (@variants) = $po->stock_orders
    ->related_resultset('stock_order_items')
    ->related_resultset('variant')->all;

my @fast_track_skus = map { $_->sku } @variants;

test_prefix('Fast track');
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Goods In/Quality Control',
    ]},
    dept => 'Distribution'
});

# no fast track checkboxes ticked = no error
$framework
    ->flow_mech__goodsin__fasttrack_deliveryid($delivery->id)
    ->flow_mech__goodsin__fasttrack_submit({
        fast_track => {},
    });

$framework->mech->no_feedback_error_ok('No fast-track error when not fast-tracking');

# fast track checked but with quantity 0 = error
$framework->errors_are_fatal(0);

$framework
    ->flow_mech__goodsin__fasttrack_deliveryid($delivery->id)
    ->flow_mech__goodsin__fasttrack_submit({
        fast_track => {
            $fast_track_skus[0] => 0,
        },
    });

$framework
    ->test_mech__app_error_message__like(
        qr/Fast track with SKU $fast_track_skus[0] has been requested with zero quantity/,
        "Error when fast-tracking zero quantity",
    );

$framework
    ->flow_mech__goodsin__fasttrack_deliveryid($delivery->id)
    ->flow_mech__goodsin__fasttrack_submit({
        fast_track => {
            $fast_track_skus[0] => 0,
            $fast_track_skus[1] => 0,
        },
    });

$framework
    ->test_mech__app_error_message__like(
        qr/Fast track with SKU $fast_track_skus[0] has been requested with zero quantity/,
        "Error for first of two zero-quantity fast-tracks should be present",
    );

$framework
    ->test_mech__app_error_message__like(
        qr/Fast track with SKU $fast_track_skus[1] has been requested with zero quantity/,
        "Error for second of two zero-quantity fast-tracks should be present",
    );

$framework->errors_are_fatal(1);

# fast track one of each sku = no error
$framework
    ->flow_mech__goodsin__fasttrack_deliveryid($delivery->id)
    ->flow_mech__goodsin__fasttrack_submit({
        fast_track => { map { $_ => 1 } @fast_track_skus },
    });

$framework->mech->no_feedback_error_ok("No error when fast-tracking with non-zero quantity");

test_prefix('Messages');

my ($pre_advice) = $xt_to_wms->expect_messages( {
    messages => [ { 'type'   => 'pre_advice' } ]
} );

my @other_files = $xt_to_wms->new_files;
is(scalar(@other_files),0,'only one pre_advice sent');


my @got_pids=sort map { $_->{pid} } @{$pre_advice->payload_parsed->{items}};

my @got_skus= map { $_->{sku} } @{$pre_advice->payload_parsed->{items}[0]{skus}};
# This should be sorted already in the PreAdvice producer in phase 1 onwards
if ($iws_rollout_phase == 0) {
    @got_skus = sort @got_skus;
}

my @want_pids=$variants[0]->product_id;
my @want_skus=sort map { $_->sku } @variants;

is_deeply(\@got_pids,\@want_pids,'correct pids');
is_deeply(\@got_skus,\@want_skus,'correct skus');

done_testing();

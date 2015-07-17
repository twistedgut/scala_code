#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

simple_channelization.t - Test requesting samples on a different channel

=head1 DESCRIPTION

Request a sample on a different channel.

Approve sample and check it's worked.

#TAGS sample fulfilment whm

=cut

use FindBin::libs;


use Test::XT::Flow;
use XTracker::Config::Local;

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :stock_process_type
    :stock_order_status
    :delivery_status
);

my $flow = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Quantity',
        'Test::XT::Data::PurchaseOrder',
        'Test::XT::Data::Location',
        'Test::XT::Data::Samples',
        'Test::XT::Flow::Samples',
        'Test::XT::Feature::Ch11n',
        'Test::XT::Feature::Ch11n::Samples',
    ],
)->new();

plan skip_all => 'This test requires the channel MRP to be enabled.'
    unless $flow
        ->schema
        ->resultset('Public::Channel')
        ->channels_enabled( qw( MRP ) );

note 'Clear all test locations';
$flow->data__location__destroy_test_locations;

my $permissions = {
    $AUTHORISATION_LEVEL__OPERATOR => [
        'Sample/Review Requests',
        'Sample/Sample Cart',
        'Sample/Sample Transfer',
        'Sample/Sample Cart Users',
        'Stock Control/Stock Check',
        'Goods In/Stock In',
        'Stock Control/Inventory',
        'Admin/Job Queue',

    ],
    $AUTHORISATION_LEVEL__MANAGER => [
        'Stock Control/Sample',
    ],
};

my $location_names = $flow->data__location__create_new_locations({
    quantity        => 3,
    channel_id      => $flow->mech->channel->id,
    allowed_types   => $flow->all_location_types,
});

note "locations : ". join(',',@{$location_names});

$flow->data__samples__create_transfer_request({'location_name' => $location_names->[0]});
    if (!$flow->attr__quantity__quantities_by_variant) {
        note "no attr__quantity__quantities_by_variant";
    }

$flow->login_with_permissions({
        dept => 'Distribution Management',
        perms => $permissions,
    })
    ->flow_mech__samples__stock_control_sample
        ->test_mech__samples__stock_control_sample_requests_ch11n
    ->flow_mech__samples__stock_control_approve_transfer
    ->flow_data__samples__update_transfer_status(
        $flow->attr__samples__stock_transfer,
        [keys %{$flow->attr__quantity__quantities_by_variant}]
    )->login_with_permissions({
        dept => 'Sample',   # need to change user dept to say samples have been received
        perms => $permissions,
    })
    ->flow_mech__samples__stock_control_sample_goodsin
        ->test_mech__samples__stock_control_sample_goodsin_ch11n
;

note 'Clearing all test locations';
# TODO: put this back
#$flow->data__location__destroy_test_locations;

done_testing;
1;

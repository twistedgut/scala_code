#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

lost_cancelled_item.t - Cancel an item, then at packing, mark it as lost

=head1 DESCRIPTION

Cancel an item, then at packing, mark it as lost.

#TAGS fulfilment packing packingexception iws prl checkruncondition whm

=cut

use FindBin::libs;


use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 ) ], export => [qw( $iws_rollout_phase $prl_rollout_phase $distribution_centre )];
use Test::XTracker::Artifacts::RAVNI;

test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
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

my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

# create and pick the order
test_prefix("Setup: order shipment");

my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2,
});
my $order_data = $framework->flow_db__fulfilment__create_order_picked(
    channel  => $channel,
    products => $pids,
);

my $shipment_id = $order_data->{shipment_id};

note "shipment $shipment_id created";

my $canceled_item = splice @$pids,1,1;
test_prefix("Setup: cancel item");
$framework->open_tab("Customer Care");
$framework->flow_mech__customercare__orderview( $order_data->{'order_object'}->id );
$framework->flow_mech__customercare__cancel_shipment_item();
$framework->flow_mech__customercare__cancel_item_submit( $canceled_item->{'sku'});
$framework->flow_mech__customercare__cancel_item_email_submit();
$framework->close_tab();

if ($prl_rollout_phase) {
    # TODO DC2A: Expect appropriate allocate/pick messages here
} else {
    $xt_to_wms->expect_messages({
        messages => [{
            details => {
                "shipment_id" => "s-$shipment_id",
            },
            'type' => "shipment_request",
        }]
    });
}

test_prefix("Setup: pack shipment");
# the canceled item should be in that tote, but we say it is not
$framework->task__packing($order_data->{shipment_object}, {
    xt_to_wms   => $xt_to_wms,
    tote        => $order_data->{tote_id},
});

test_prefix("PIPEO");
$xt_to_wms->expect_messages({
    messages => [{
        details => {
            "shipment_id" => "s-$shipment_id",
            items => [ { sku => $canceled_item->{sku}, quantity => 1 } ],
            "from" => { container_id => $order_data->{tote_id} },
            "to" => { place => "lost" },
        },
        'type' => "item_moved",
    }]
});
my $log_record = $framework->schema->resultset('Public::LogStock')
    ->search(
        {
            variant_id => $canceled_item->{variant_id},
            notes => { -ilike => 'missing cancelled item %' },
        },
        { order_by => 'date DESC', rows => 1 }
    )->single;
ok($log_record,'we logged it');
is($log_record->quantity,-1,'with a change of -1');

done_testing();

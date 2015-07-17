#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

manual_pick_qc_fail.t - Pick an item and fail Quality Control

=head1 DESCRIPTION

Pick an item and fail Quality Control.

Verify user is instructed to send to Packing Exception.

#TAGS fulfilment picking packing packingexception http whm

=cut

use FindBin::libs;

use Test::XT::Flow;
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XTracker::Data;
use Test::XT::Data::Container;
use Test::Differences;
use Data::Dump 'pp';

use Test::XTracker::Artifacts::RAVNI;
use XTracker::Config::Local 'config_var';

use Test::XTracker::RunCondition iws_phase => 0, prl_phase => 0;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection'
    ]}
});
$framework->mech->force_datalite(1);

my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2
});

my $product_data =
    $framework->flow_db__fulfilment__create_order(
        channel => $channel,
        products => [ $pids->[0], $pids->[0], $pids->[1] ],
    );

my $shipment_id = $product_data->{'shipment_id'};

# Select the order, and start the picking process
my $picking_sheet =
    $framework->flow_task__fulfilment__select_shipment_return_printdoc( $shipment_id );

$framework
    ->flow_mech__fulfilment__picking
    ->flow_mech__fulfilment__picking_submit( $shipment_id );

my ($tote_id) = Test::XT::Data::Container->get_unique_ids({ how_many => 1 });

# Pick the items according to the pick-sheet
for my $item (@{ $picking_sheet->{'item_list'} }) {
    my $location = $item->{'Location'};
    my $sku      = $item->{'SKU'};

    $framework->flow_mech__fulfilment__picking_pickshipment_submit_location( $location );
    $framework->flow_mech__fulfilment__picking_pickshipment_submit_sku( $sku );
    $framework->flow_mech__fulfilment__picking_pickshipment_submit_container( $tote_id );
}

$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $shipment_id );

my $data = $framework->mech->as_data();

$framework->errors_are_fatal(0);
$framework->flow_mech__fulfilment__packing_checkshipment_submit(
    fail => {
        $data->{shipment_items}[0]{shipment_item_id} => 'foo',
    }
);

is($framework->mech->uri->path,
   '/Fulfilment/Packing/PlaceInPEtote',
   'pack QC fail requires putting items into another tote');
like($framework->mech->app_error_message,
     qr{send to the packing exception desk},
     'packer asked to send shipment to exception desk');
$framework->errors_are_fatal(1);

done_testing();

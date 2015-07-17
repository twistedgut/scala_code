#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

fail_at_packing.t - Fail an item at packing and check we behave appropriately

=head1 DESCRIPTION

Only runs in IWS phase. However this test is not IWS-specific, we should make
it work with PRLs too (should just be a matter of changing the picking).

Create an customer order shipment in a state of I<Selected> with three items.

Send a I<shipment_ready> with all three items in the same container.

Start packing the shipment and mark the first item as failed.

Check that we were redirected to PlaceInPEtote

Check that the operator is told to send the shipment to the packing exception
desk

#TAGS packingexception fulfilment packing checkruncondition iws whm

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

use Test::XTracker::RunCondition iws_phase => 'iws', dc => 'DC1';

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]}
});
$framework->mech->force_datalite(1);

my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 2
});

my $product_data =
    $framework->flow_db__fulfilment__create_order_selected(
        channel => $channel,
        products => [ $pids->[0], $pids->[0], $pids->[1] ],
    );

my $shipment_id = $product_data->{'shipment_id'};

my ($container_id) = Test::XT::Data::Container->get_unique_ids({ how_many => 1 });

# Fake a ShipmentReady from IWS
$framework->flow_wms__send_shipment_ready(
    shipment_id => $shipment_id,
    container => {
        $container_id => [ map { $_->{'sku'} } @{ $product_data->{'product_objects'} } ]
    },
);

$framework
    ->flow_mech__fulfilment__select_packing_station
    ->flow_mech__fulfilment__select_packing_station_submit( channel_id => $channel->id )
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

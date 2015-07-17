#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

resume_pipe.t - Resume a container on the "Put In Packing Exception" page

=head1 DESCRIPTION

Resume a container on the "Put In Packing Exception" page.

#TAGS fulfilment packing packingexception whm

=cut

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use Carp::Always;
use Data::Dump 'pp';
use XTracker::Config::Local qw(config_var);

test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::PipePage',
        'Test::XT::Flow::Fulfilment',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection'
    ]},
});
$framework->mech->force_datalite(1);

test_prefix("Setup: order");

my $order_data = $framework->flow_db__fulfilment__create_order_picked(
    products => 3,
);

my $src_tote = $order_data->{tote_id};
my @dest_totes = Test::XT::Data::Container->get_unique_ids({ how_many => 2 });
my @items = $order_data->{shipment_object}->shipment_items->all;


test_prefix("First PIPE");

my $channel_id =  $order_data->{channel_object}->id;
$framework->mech__fulfilment__set_packing_station( $channel_id );

$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $src_tote );
$framework->catch_error(
    qr{send to the packing exception desk},
    'QC fail',
    flow_mech__fulfilment__packing_checkshipment_submit =>
        fail => {
            $items[0]->id => 'foo',
        }
    );
$framework
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $items[0]->get_sku )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $dest_totes[0] );

test_prefix("Resume PIPE");

$framework
    ->flow_mech__fulfilment__packing
    ->catch_error(
        qr{send the container \w+ to the packing exception desk, then scan another one},
        'packer asked to send PE tote away',
        flow_mech__fulfilment__packing_submit => $dest_totes[0],
    )
    ->catch_error(
        qr{Please continue},
        'packer asked to continue PIPE',
        flow_mech__fulfilment__packing_submit => $src_tote,
    );
$framework->assert_location(qr!^/Fulfilment/Packing/PlaceInPEtote!);
$framework
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $items[1]->get_sku )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $dest_totes[1] )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $items[2]->get_sku )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $dest_totes[1] )
    ->flow_mech__fulfilment__packing_placeinpetote_mark_complete();
$framework->assert_location(qr!^/Fulfilment/Packing/EmptyTote!);

done_testing();


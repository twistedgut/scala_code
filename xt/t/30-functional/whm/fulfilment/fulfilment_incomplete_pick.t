#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

fulfilment_incomplete_pick.t - Test incomplete pick goes on hold

=head1 DESCRIPTION

This tests the basic shipment on hold functionality when there's an incomplete
pick during manual picking in XT. It doesn't cover picking in IWS or a PRL.

Create a shipment - select it and pick it. Return a I<pick_commenced> message
followed by an I<incomplete_pick> one

Go to the order view page and check the on hold reason is incomplete pick.

#TAGS phase0 fulfilment picking holdshipment setupselection whm

=cut

use FindBin::libs;

use Test::XTracker::RunCondition iws_phase => 0, prl_phase => 0;


use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Database qw(:common);
use Test::XTracker::LocationMigration;
use Test::XTracker::Data;
use Test::XT::Data::Container;
use Test::Differences;
use Test::XTracker::Artifacts::RAVNI;
use XTracker::Config::Local qw( config_var );

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection',
        'Customer Care/Customer Search',
    ]}
});
my $schema = Test::XTracker::Data->get_schema;

# Create the order with five products
my $product_count = 5;
my $product_data =
    $framework->flow_db__fulfilment__create_order( products => $product_count );
my $shipment_id = $product_data->{'shipment_id'};
my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );

# Save a LocationMigration test for each variant
my @location_migration_tests;
for my $product ( @{ $product_data->{'product_objects'} } ) {
    my $test = Test::XTracker::LocationMigration->new(
        variant_id => $product->{'variant_id'}, debug => 0
    );
    $test->snapshot("Before picking");
    push( @location_migration_tests, $test );
}

my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');

# Select the order, and start the picking process
$framework
    ->flow_mech__fulfilment__selection
    ->flow_mech__fulfilment__selection_submit( $shipment_id )
    ->flow_mech__fulfilment__picking
    ->flow_mech__fulfilment__picking_submit( $shipment_id );

$wms_to_xt
    ->expect_messages( {  messages => [ { type => 'picking_commenced' } ] } );

$framework->flow_mech__fulfilment__picking_incompletepick();

$wms_to_xt
    ->expect_messages( {  messages => [ { type => 'incomplete_pick' } ] } );

$framework->flow_mech__customercare__orderview( $product_data->{'order_object'}->id );

is( $framework->mech->as_data->{'meta_data'}->{'Shipment Hold'}->{'Reason'},
    'Incomplete Pick', "Order is on hold for Shipment Pick" );

done_testing();

#!/usr/bin/env perl

=head1 NAME

packing_invalid_state.t - Test invalid shipment/shipment_item combination at packing

=head1 DESCRIPTION

Test that if we force a shipment/shipment_item combination into an incorrect
state, xtracker deals with this ok at packing and packing exception.

Login as customer care, create an single-item order and cancel it. Hack an
incorrect state as we don't know how it was reproduced - make the item
I<Picked> and keep the shipment as I<Cancelled>, and place it in a container
with a status of I<Picked Items>.

Try and pack the shipment and receive a shipment is in incorrect state message.

Check the container has a status of I<Packing Exception Items>.

Try and process the shipment at packing exception and get an incorrect state
error message.

#TAGS fulfilment packingexception packing cancelorder whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::More::Prefix qw/test_prefix/;
use Test::Differences;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status :container_status);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;

use Test::XTracker::RunCondition iws_phase => 'iws', export => qw( $iws_rollout_phase );


test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Data::Location',
        'Test::XT::Flow::WMS',
    ],
);
my $schema = $framework->schema;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

test_prefix("Create broken shipment");

my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 1 });

my $order_data = $framework->flow_db__fulfilment__create_order( channel  => $channel, products => [ $pids->[0] ], );
note "shipment $order_data->{'shipment_id'} created";

$framework
    ->flow_mech__customercare__cancel_order( $order_data->{'order_object'}->id )
    ->flow_mech__customercare__cancel_order_submit
    ->flow_mech__customercare__cancel_order_email_submit;

is( $framework->mech->as_data->{'meta_data'}->{'Order Details'}->{'Order Status'},
    'Cancelled', 'Order has been cancelled');

my $shipment_item_rs = $schema->resultset('Public::ShipmentItem')->search({
    'shipment_id' => $order_data->{shipment_id}
});
is ($shipment_item_rs->count(), 1, "Shipment has one shipment_item");

# We've not been able to work out what weird sequence of events causes
# the shipment_item to be able to have a status of Picked while the
# shipment is Cancelled, so we have to just force the badness manually
# here for the purposes of testing what happens next.
$schema->resultset('Public::Container')->create({
    'id' => $container_id,
    'status_id' => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
});
$shipment_item_rs->first->update({
    'shipment_item_status_id' => $SHIPMENT_ITEM_STATUS__PICKED,
    'container_id' => $container_id,
});

test_prefix("Try to pack broken shipment");
$framework->flow_mech__fulfilment__packing;
$framework->errors_are_fatal(0);
$framework->flow_mech__fulfilment__packing_submit( $container_id );
is ($framework->mech->app_error_message,
      "This shipment contains items in an incorrect state. Please send the container $container_id to the packing exception desk, then scan another one.",
      "Tell packer to send the container to packing exception");
$framework->errors_are_fatal(1);

my $container = $schema->resultset('Public::Container')->find($container_id);
is ($container->status_id,
    $PUBLIC_CONTAINER_STATUS__PACKING_EXCEPTION_ITEMS,
    "Container status has been updated");

test_prefix("At packing exception");
$framework->flow_mech__fulfilment__packingexception;
$framework->errors_are_fatal(0);
$framework->flow_mech__fulfilment__packingexception_submit( $container_id );
is ($framework->mech->app_error_message,
      "Container $container_id has shipment items from shipment $order_data->{shipment_id} in an incorrect state, please report this issue to service desk.",
      "Tell PE supervisor to raise issue with service desk");
$framework->errors_are_fatal(1);


done_testing();




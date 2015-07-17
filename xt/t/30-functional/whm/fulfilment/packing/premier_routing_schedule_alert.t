#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];

=head1 NAME

premier_routing_schedule_alert.t - Premier customers are alerted of an impending delivery

=head1 DESCRIPTION

Verify that premier customers are alerted of an impending delivery when packing
is complete.

Premier shipments that have a routing schedule record should send alerts to
the customer, informing them when their shipment will be delivered. Do this
when packing is complete.

Originally done for CANDO-80

#TAGS fulfilment packing checkruncondition whm

=cut

use strict;
use warnings;
use FindBin::libs;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];

use DateTime;

use Test::XTracker::Data;
use Test::XT::Flow;
use Test::XT::Data::Container;

use XTracker::Config::Local             qw( sys_config_groups config_var );
use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :customer_category
                                            :routing_schedule_type
                                            :routing_schedule_status
                                            :shipment_type
                                        );
use XTracker::DHL::RoutingRequest qw( set_dhl_destination_code );

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);

$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [ 'Fulfilment/Packing' ]},
    dept => 'Customer Care'
});

my $order_dets  = $framework->flow_db__fulfilment__create_order_picked( channel => 'nap', products => 2 );
my $tote_id     = $order_dets->{tote_id};
my $order       = $order_dets->{order_object};
my $customer    = $order_dets->{customer_object};
my $channel     = $order_dets->{channel_object};
my $shipment    = $order_dets->{shipment_object};
my @ship_items  = $shipment->shipment_items->all;

note "Order Id/Nr: " . $order->id . "/" . $order->order_nr;
note "Shipment Id: " . $shipment->id;

if ( config_var('DHL', 'xmlpi_region_code') eq 'AM' )  {
    my $dbh = $framework->schema->storage->dbh;
    fail('Remove obsolete block of code that fixes previous test failure')
        if ( $shipment->destination_code && $shipment->is_carrier_automated );
    set_dhl_destination_code( $dbh, $shipment->id, 'LHR' );
    $shipment->set_carrier_automated( 1 );
    is( $shipment->is_carrier_automated, 1, "Shipment is now Automated" );
}

# set-up the data to make sure Alerts get sent
$customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );
$shipment->update( { shipment_type_id => $SHIPMENT_TYPE__PREMIER, mobile_telephone => '+44712345678' } );
my $sched_rec   = $framework->schema->resultset('Public::RoutingSchedule')->create( {
                                                                routing_schedule_type_id    => $ROUTING_SCHEDULE_TYPE__DELIVERY,
                                                                routing_schedule_status_id  => $ROUTING_SCHEDULE_STATUS__SCHEDULED,
                                                                external_id                 => '9999',
                                                                task_window_date            => DateTime->now(),
                                                                task_window                 => '13:00 to 15:30',
                                                                driver                      => 'Sally',
                                                                run_number                  => 47,
                                                                run_order_number            => 3,
                                                        } );
$shipment->create_related( 'link_routing_schedule__shipments', { routing_schedule_id => $sched_rec->discard_changes->id } );

# set-up what to expect in the tests
my $ship_email_logs = $shipment->shipment_email_logs->search( {}, { order_by => 'id DESC' } );
my $expected_logs   = 0;
$expected_logs++    if ( Test::XTracker::Data->is_method_enabled_for_subject( $channel, 'Premier Delivery', 'SMS' ) );
$expected_logs++    if ( Test::XTracker::Data->is_method_enabled_for_subject( $channel, 'Premier Delivery', 'Email' ) );
$ship_email_logs->delete;

$framework->mech__fulfilment__set_packing_station( $channel->id );

# start Packing
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $tote_id )
    ->flow_mech__fulfilment__packing_checkshipment_submit();

foreach my $item ( @ship_items ) {
    $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $item->get_sku );
}

# Submit box id's plus a container id
$framework
    ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
        channel_id => $channel->id,
        tote_id    => Test::XT::Data::Container->get_unique_id(),
    );

# submit waybill if expect_AWB is set in config
$framework->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789") if config_var('DistributionCentre','expect_AWB');

# check that no alerts have been sent before 'Complete Packing' happens
note "Pre Complete Packing";
cmp_ok( $sched_rec->discard_changes->notified, '==', 0, "Routing Schedule Record 'notified' flag is still FALSE" );
cmp_ok( $ship_email_logs->reset->count(), '==', 0, "No Shipment Email Logs have been created" );

$framework->flow_mech__fulfilment__packing_packshipment_complete;

note "Post Complete Packing";
cmp_ok( $sched_rec->discard_changes->notified, '==', ( $expected_logs ? 1 : 0 ),
                                "Routing Schedule Record 'notified' flag should be " . ( $expected_logs ? "TRUE" : "FALSE" ) );
cmp_ok( $ship_email_logs->reset->count(), '==', $expected_logs, "Expected number of Shipment Email Logs have been Created: $expected_logs" );

done_testing;

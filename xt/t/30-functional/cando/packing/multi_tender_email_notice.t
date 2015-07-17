#!/usr/bin/env perl

=pod

Test to check that the print docs are generated as expected at packing

Currently only checks the matchup_sheet cos that's what I'm working on, but can be extended
at a later date to test other print docs as required

=cut

use NAP::policy qw/test/;
use FindBin::libs;

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Config::Local qw( config_var
                                send_multi_tender_notice_for_country
                                :carrier_automation
                              );

use XTracker::Constants::FromDB qw( :authorisation_level
                                    :shipment_item_status
                                    :renumeration_type
                                  );

use XTracker::Database qw(:common);
use XTracker::Database::Shipment qw(set_carrier_automated check_country_paperwork);
use XTracker::DHL::RoutingRequest qw( set_dhl_destination_code );

use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;
use Carp::Always;

# Set up framework
test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);

# log in
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Selection',
        'Fulfilment/Picking',
        'Fulfilment/Packing',
        'Fulfilment/Labelling',
        'Fulfilment/Airwaybill',
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);
my $schema = $framework->schema;

# We need a Russian shipping address for this test
my $russian_address = Test::XTracker::Data->create_order_address_in('Russia');

# create, pick and pack the order using a non automated carrier - matchup doc should be printed
test_prefix("Setup: create, pick and pack the non-automated order");
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 1 });
my $config_section  = $channel->business->config_section;
my $order_data = $framework->flow_db__fulfilment__create_order_picked( channel  => $channel,
                                                                       products => $pids,
                                                                       address  => $russian_address,
                                                                       create_renumerations => 1,
                                                                     );
note "shipment $order_data->{'shipment_id'} created";
my $shipment_row = $schema->resultset('Public::Shipment')->find( $order_data->{'shipment_id'} );
is( $shipment_row->is_carrier_automated, 0, "Shipment is not Automated" );
# TODO - Remove this section below and refactor test as DHL shipments with a
# valid address will be automated -> when merged with WHM-4653
if ( config_var('DHL', 'xmlpi_region_code') eq 'AM' )  {
    my $dbh = $schema->storage->dbh;
    fail('Remove obsolete block of code that fixes previous test failure')
        if ( $shipment_row->destination_code && $shipment_row->is_carrier_automated );
    set_dhl_destination_code( $dbh, $shipment_row->id, 'LHR' );
    $shipment_row->set_carrier_automated( 1 );
    is( $shipment_row->is_carrier_automated, 1, "Shipment is now Automated" );
}

# get rid of any Internal Email Logs
$shipment_row->shipment_internal_email_logs->delete;

my $order = $order_data->{order_object};
$order->create_related( 'tenders', {
    rank    => 0,
    value   => 10,
    type_id => $RENUMERATION_TYPE__STORE_CREDIT,
} );

$order->create_related( 'tenders', {
    rank    => 1,
    value   => 110,
    type_id => $RENUMERATION_TYPE__CARD_DEBIT,
} );

ok( $shipment_row->shipment_address->country eq 'Russia',
    "The shipment is going to Russia" );

ok( send_multi_tender_notice_for_country( $schema, $shipment_row->shipment_address->country ),
    "We should be sending a multi tender email notice email" );

ok( $order->card_debit_tender, "The order has a card tender" );
ok( ( $order->store_credit_tender || $order->voucher_tenders->count ),
    "The order also has a store credit or voucher tender" );

$framework->mech__fulfilment__set_packing_station( $channel->id );

$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $order_data->{tote_id} )
    ->flow_mech__fulfilment__packing_checkshipment_submit()
    ->flow_mech__fulfilment__packing_packshipment_submit_sku($pids->[0]->{sku})
    ->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $order_data->{channel_object}->id );

# The waybill is only submitted if expect_AWB is set to 1 in config
$framework->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789")
    if ( config_var('DistributionCentre','expect_AWB') );
$framework->flow_mech__fulfilment__packing_packshipment_complete;

# TODO: All DCs are printing at packing...so labeling is not relevant anymore
# $framework->task__labelling( $shipment_row );

my $to_email = config_var( "Email_${config_section}", 'multi_tender_notice_email' );
my $internal_email_log = $schema->resultset('Public::ShipmentInternalEmailLog')->search( {
    shipment_id => $shipment_row->id,
    subject     => 'RUSSIA SHIPMENT WITH DUAL TENDER',
    recipient   => $to_email,
} );

ok( $internal_email_log->count == 1, "There is a shipment_internal_email_log entry" );

done_testing;

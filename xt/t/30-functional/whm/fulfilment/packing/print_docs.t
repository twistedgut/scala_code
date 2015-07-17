#!/usr/bin/env perl

=head1 NAME

print_docs.t - Verify printed documentation is generated as expected at packing

=head1 DESCRIPTION

Test to check that the print docs are generated as expected at packing.

#TAGS fulfilment packing todo whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Config::Local;
use XTracker::Constants::FromDB qw(:authorisation_level :shipment_item_status);
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
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);
my $schema = $framework->schema;

#watch the printdocs directory
my $print_directory = Test::XTracker::PrintDocs->new(filter_regex => qr{\.(?:html|lbl)$});

# This would be a totally awesome test if I could uncomment it.
# But I can't because the proxy is a big pile of steaming poo and I've
# not got time to find a workaround
#
#set_carrier_automated( $dbh, $order_data->{'shipment_id'}, 1 );
#is( $schema->resultset('Public::Shipment')->find( $order_data->{'shipment_id'} )->is_carrier_automated, 1, "Shipment is Automated" );
#


# create, pick and pack the order using a non automated carrier
test_prefix("Setup: create, pick and pack the non-automated order");
my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 1 });
my $order_data = $framework->flow_db__fulfilment__create_order_picked( channel  => $channel, products => $pids, );
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

$framework->mech__fulfilment__set_packing_station( $channel->id );

$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $order_data->{tote_id} )
    ->flow_mech__fulfilment__packing_checkshipment_submit()
    ->flow_mech__fulfilment__packing_packshipment_submit_sku($pids->[0]->{sku})
    ->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $order_data->{channel_object}->id );

$framework->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789") if config_var('DistributionCentre','expect_AWB');
$framework->flow_mech__fulfilment__packing_packshipment_complete;

test_prefix("Test printdoc generation");

my $number_of_files = 0;
my @expected_file_types;

push @expected_file_types, (
    qr/^invoice$/,
    qr/^label$/,
    ( qr/_archive$/)x!! $shipment_row->requires_archive_label );

$number_of_files += @expected_file_types;

# ... and perhaps outward/return proformas depending on the country
my $shipping_country = $order_data->{address_object}->country;
my ($expected_outpro, $expected_retpro) = check_country_paperwork( $schema->storage->dbh, $shipping_country );
if($expected_outpro) {
    $number_of_files++;
    push @expected_file_types, qr/^outpro$/;
}
if($expected_retpro) {
    $number_of_files++;
    push @expected_file_types, qr/^retpro$/;
}

# If the shipment is not carrier-automated, we expect a shipping-form
if(!$shipment_row->is_carrier_automated) {
    $number_of_files++;
    push @expected_file_types, qr/^shippingform$/;
}

my @print_docs = $print_directory->wait_for_new_files( files => $number_of_files );
my @actual_file_types = map { $_->file_type } @print_docs;

for my $expected_file_type (@expected_file_types) {
    ok((grep { $_ =~ $expected_file_type } @actual_file_types), "Expected file type '$expected_file_type' found");
}

done_testing;

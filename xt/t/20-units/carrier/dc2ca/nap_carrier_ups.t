#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

nap.carrier.ups.t - Tests for NAP::Carrier::UPS

=head1 DESCRIPTION

Tests that a creation of a NAP::Carrier object creation correctly returns a
NAP::Carrier::UPS object, and does a few basic can_ok tests.

#TAGS carrier ups shouldbeunit sensitive

=cut


use Data::Dump qw(pp);


use FindBin::libs;

use XTracker::Constants::FromDB qw( :channel );
use XTracker::Constants qw< $APPLICATION_OPERATOR_ID >;

use Test::XTracker::Data;
use Test::XTracker::RunCondition dc => 'DC2';

# this forces connections to the same DB & forces the
# use of the same config files as the Test Harness
use Test::XTracker::Carrier;

use XTracker::Database qw<get_database_handle>;

################################################################################
use_ok('Net::UPS');
use_ok('NAP::Carrier');
use_ok('NAP::Carrier::UPS');

# Yummy Globals
my ($nc, $carrier_test, $schema, $ups_shipment, $ups_shipment_id);

# something to give us useful objects/records to test with
$carrier_test = Test::XTracker::Carrier->new;

# we'll need a schema to pass to new()
$schema = $carrier_test->schema;

# Get a Shipment ID to work with
$ups_shipment = $carrier_test->ups_shipment;
$ups_shipment_id = $ups_shipment->id;
ok(defined($ups_shipment_id), '$ups_shipment_id is defined');
note "\$ups_shipment_id is $ups_shipment_id";

# Create a NAP::Carrier object for the shipment
$nc = NAP::Carrier->new({schema=>$schema,shipment_id=>$ups_shipment_id,operator_id=>$APPLICATION_OPERATOR_ID});
isa_ok($nc, 'NAP::Carrier::UPS', 'correct return type of ::UPS');

can_ok(
    $nc,
    qw<
        _build_net_ups
        config
        deduce_autoable
        is_autoable
        manifest
        net_ups
        prepare_ups_address
        service_errors
        _set_service_errors
        _set_ups_address
        book_shipment_for_automation
        shipping_accept_request
        shipping_confirm_request
        ups_address
        validate_address
    >
);


can_ok(
    $nc->config,
    qw<
        username
        password
        xml_access_key
        base_url
        av_service
        shipconfirm_service
        shipaccept_service
        quality_rating_threshold
        max_retry_wait_time
        max_retries
        fail_warnings
    >
);



done_testing;

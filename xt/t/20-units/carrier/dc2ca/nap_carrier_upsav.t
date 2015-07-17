#!/usr/bin/env perl

use NAP::policy 'test';

=head1 NAME

nap.carrier_upsav.t - Tests for NAP::Carrier::UPS's address validation

=head1 DESCRIPTION

#TAGS carrier ups

=cut

use FindBin::libs;

# this forces connections to the same DB & forces the
# use of the same config files as the Test Harness
use Test::XTracker::Data;
use Test::XTracker::Mock::Net::UPS;
use Test::XTracker::RunCondition dc => 'DC2';
use Test::XTracker::Carrier;
use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );

#
# http://confluence.net-a-porter.com/display/BA/DC2+carrier+automation+-+Technical+Specification#DC2carrierautomation-TechnicalSpecification-2.IntegratewithUPSaddressvalidationservice
#

use_ok('NAP::Carrier');
use_ok('NAP::Carrier::UPS');

# use a mock UPS object for reliable tests on external service
my $mock_object = Test::XTracker::Mock::Net::UPS->new(
        addresses => [
            {length => 1, postal_code => 10001, city => 'NEW YORK', state => 'NY'},
        ],
    )
    ->mock('validate_address');


# something to give us useful objects/records to test with
my $carrier_test = Test::XTracker::Carrier->new;

my $schema = $carrier_test->schema;

# save the current automation states
my $auto_states = $schema->resultset('Public::Channel')->get_carrier_automation_states();

my $ups_shipment = $carrier_test->ups_shipment;
Test::XTracker::Data->set_carrier_automation_state( $ups_shipment->shipping_account->channel->id, 'On' );

#
##
### UPS AV tests [based on flowchart]
##
#
# put all this in a transaction so we can rollback at the end
$schema->txn_dont( sub {
    # XXX this is a bit naughty, but we don't currently have anything that
    # will return a ::UPS carrier
    # TODO - add/get data so we can test ::UPS properly
    diag "TODO: add/get data so we can test ::UPS properly";
    my $ncu = NAP::Carrier->new(
        {shipment_id => $ups_shipment->id,operator_id=>$APPLICATION_OPERATOR_ID}
    );
    isa_ok($ncu, 'NAP::Carrier::UPS', 'correct return type of ::UPS');
    can_ok($ncu, qw<config>);

    # update shipment with a decent address
    $ups_shipment->shipment_address->update( {
        towncity    => "Pittsburgh",
        county      => "PA",
        postcode    => "15228",
        country     => "United States",
    } );

    # get basig UPS conf
    my $config = $ncu->config;
    isa_ok($config, 'NAP::Carrier::UPS::Config', 'correct return type of ::UPS->config');

    # get the QRT (quality rating threshold)
    ok( defined($config->quality_rating_threshold),
        'quality_rating_threshold is defined' );

    # query address / get address for shipment
    my $shipment_address = $ncu->shipment->shipment_address;
    diag $shipment_address;

    # change the base url in the config to point to
    # UPS's live servers (cie = test)
    $config->{base_url} =~ s/wwwcie\./www\./;
    unlike( $ncu->net_ups->av_proxy, qr/wwwcie/, 'Net::UPS av_proxy not pointing to live servers: '.$ncu->net_ups->av_proxy );

    # make request to LIVE servers
    my $res = $ncu->validate_address;
    cmp_ok( $res, '==', 1, 'UPS AV Returned TRUE' );
} );

# restore the automation states
Test::XTracker::Data->restore_carrier_automation_state( $auto_states );

done_testing;

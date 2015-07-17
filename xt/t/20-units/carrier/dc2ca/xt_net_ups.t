#!/usr/bin/env perl

=head1 NAME

xt.net.ups.t - Tests for XT::Net::UPS

=head1 DESCRIPTION

#TAGS carrier ups shouldbeunit sensitive

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::LoadTestConfig;
use XTracker::Config::Local;

if(!config_var('UPS', 'enabled') ) {
    plan skip_all => 'Only runs tests where UPS is enabled';
}

use Data::Dump qw(pp);
use XTracker::Constants::FromDB     qw( :channel );

# this forces connections to the same DB & forces the
# use of the same config files as the Test Harness
use Test::XTracker::Data;
use NAP::Carrier::UPS::Config;

use Test::XTracker::Carrier;
use Test::XT::Net::UPS;

my $carrier_test= Test::XTracker::Carrier->new;
my $schema = $carrier_test->schema();
my @channels = $schema->resultset('Public::Channel')->search( {'is_enabled' => 1}, { order_by => 'me.id ASC' } )->all;

# save the current state of Carrier Automation for each Sales Channel
my $auto_states = $schema->resultset('Public::Channel')->get_carrier_automation_states();

# turn 'On' all sales channels for Automation
map { Test::XTracker::Data->set_carrier_automation_state( $_->id, 'On' ) } @channels;

# get the config for UPS
note("TEST config section");
my $config = NAP::Carrier::UPS::Config->new_for_unknown_business();

# create a new object
my $net_ups = XT::Net::UPS->new({
    config => $config,
});

# make sure the shipment has a good address
Test::XTracker::Data->ca_good_address( $carrier_test->ups_shipment );

# add in a shipment
my $shipment_obj = $carrier_test->ups_shipment;
# update the Shipment to make sure Delivery Signature is Required
$shipment_obj->update( { signature_required => 1 } );

# and mock the methods which make external API calls
use Test::XTracker::Mock::Net::UPS;
my $mock_object = Test::XTracker::Mock::Net::UPS->new(
    addresses => [
        {length => 1, postal_code => 10001, city => 'NEW YORK', state => 'NY'},
    ],
    shipping => [
        {error => 'The XML document is well formed but the document is not valid'},
        {error => 'Address Validation Error on ShipTo address'},
        {success => 1, shipment_digest => 'qwertylongstring', customer_context => 'OUTBOUND-'.$shipment_obj->id},
        {success => 1},
        {error => 'Missing or invalid shipment digest' },
        {success => 1},
        {success => 1},

        # per sales channel for last set of tests
        map { {success => 1} } ( 1..12 ),
        map { {success => 1} } ( 1..12 ),
        map { {success => 1} } ( 1..12 ),
        map { {success => 1} } ( 1..12 ),
    ],
)->mock('validate_address', 'post');

note("TEST 'xml_request' method");

# get the data again for shipping confirm
my $shpcnf_data = $net_ups->_prepare_shipping_confirm_xml($shipment_obj);
# make a call, should fail as there is a bit of the document missing
$net_ups->xml_request($shipment_obj, $shpcnf_data);
is( $net_ups->error, 'The XML document is well formed but the document is not valid', 'Got back doc not valid error' );
cmp_ok( $net_ups->xml_response->{Response}{ResponseStatusCode}, '==', 0, 'Response was Failure (0)' );
# populate the service section of the request with anything just to make the xml complete
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{Service} = {
    Code        => '01',
    Description => 'Carrier Pigeon',
};
# screw-up the address
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{ShipTo}{Address}{City}             = '';
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{ShipTo}{Address}{PostalCode}       = '';
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{ShipTo}{Address}{StateProvinceCode}= '';
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{ShipTo}{EMailAddress}  = 'backend@net-a-porter.com';
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{ShipTo}{PhoneNumber}   = '';
# make a call again, should fail as the Ship To address will be 'scrubbed'
$net_ups->xml_request($shipment_obj, $shpcnf_data);
is( $net_ups->error, 'Address Validation Error on ShipTo address', 'Got back ShipTo address not valid error' );
cmp_ok( $net_ups->xml_response->{Response}{ResponseStatusCode}, '==', 0, 'Response was Failure (0)' );
# clean-up the ShipTo address and other details
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{ShipTo}{Address}{City}             = 'Pittsburgh';
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{ShipTo}{Address}{PostalCode}       = '15228';
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{ShipTo}{Address}{StateProvinceCode}= 'PA';
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{ShipTo}{EMailAddress}              = 'backend@net-a-porter.com';
$shpcnf_data->{ShipmentConfirmRequest}{Shipment}{ShipTo}{PhoneNumber}               = '';
# make the call again
$net_ups->xml_request($shipment_obj, $shpcnf_data );
ok( exists( $net_ups->xml_response->{ShipmentDigest} ), 'Got back Shipment Digest in response' );
cmp_ok( $net_ups->xml_response->{Response}{ResponseStatusCode}, '==', 1, 'Response was Success (1)' );
my $success_response    = $net_ups->xml_response;       # save the success response for later ShipAccept tests
# make another call to the function that should die
$net_ups->xml_request($shipment_obj, $shpcnf_data, { XMLout => 'THIS SHOULD DIE' } );
like( $net_ups->error, qr/THIS SHOULD DIE/, 'Got die message in error' );
cmp_ok( $net_ups->xml_response->{Response}{ResponseStatusCode}, '==', 0, 'Response was Failure (0)' );


#
# call shipping_accept; it should:
#  - set the proxy
note "TEST 'prepare_shipping_accept_xml' method";

# firt call without and xml_response and it should return undef
$net_ups->set_xml_response( undef );
my $shpacpt_data= $net_ups->prepare_shipping_accept_xml;
is( $shpacpt_data, undef, "prepare_shipping_accept_xml called without xml_response returns 'undef'" );

# it will need $net_ups->xml_response set first which should have been done by the above tests
$net_ups->set_xml_response( $success_response );        # set using the above succesful response
$shpacpt_data   = $net_ups->prepare_shipping_accept_xml;
isa_ok( $shpacpt_data, 'HASH', 'what prepare_shipping_accept_xml returned' );
is_deeply( $shpacpt_data->{ShipmentAcceptRequest}{Request}{TransactionReference},
           $shpcnf_data->{ShipmentConfirmRequest}{Request}{TransactionReference},
           'Transaction Ref for both ShipConfirm and ShipAccept requests are the same' );
ok( exists( $shpacpt_data->{ShipmentAcceptRequest}{ShipmentDigest} ), 'ShipmentDigest key exists' );
like(
    $net_ups->proxy,
    qr{\Ahttps?://www(?:cie)\.ups\.com/ups\.app/xml/ShipAccept\z}xms,
    'proxy set to ShipAccept'
);
note $net_ups->proxy;
$net_ups->xml_request($shipment_obj, $shpacpt_data, { XMLin => { ForceArray => [ 'PackageResults' ] } } );
ok( exists( $net_ups->xml_response->{ShipmentResults} ), 'Got back Shipment Results in response' );
cmp_ok( $net_ups->xml_response->{Response}{ResponseStatusCode}, '==', 1, 'Response was Success (1)' );
isa_ok( $net_ups->xml_response->{ShipmentResults}{PackageResults}, 'ARRAY', 'PackageResults in Response' );
# let's set up a bad request
delete $shpacpt_data->{ShipmentAcceptRequest}{ShipmentDigest};
$net_ups->xml_request($shipment_obj, $shpacpt_data, { XMLin => { ForceArray => [ 'PackageResults' ] } } );
cmp_ok( $net_ups->xml_response->{Response}{ResponseStatusCode}, '==', 0, 'Response was Un-Successful (0)' );
like( $net_ups->error, qr/Missing or invalid shipment digest/, 'Got missing shipment digest in error' );


#
# try a RETURN request from ShipConfirm thru to ShipAccept with
#     supposably correct data
#
note "TEST a 'RETURN request' from ShipConfirm thru to ShipAccept";

# get the request data and clean it up a bit
my $shpcnf_retdata = $net_ups->_prepare_shipping_confirm_xml($shipment_obj, { is_return => 1 } );
# populate the service section of the request with the return service code
$shpcnf_retdata->{ShipmentConfirmRequest}{Shipment}{Service} = {
    Code        => '02',
    Description => 'Carrier Pigeon Flying Backwards',
};
# clean-up the ShipFrom address and other details
$shpcnf_retdata->{ShipmentConfirmRequest}{Shipment}{ShipFrom}{Address}{City}             = 'Pittsburgh';
$shpcnf_retdata->{ShipmentConfirmRequest}{Shipment}{ShipFrom}{Address}{PostalCode}       = '15228';
$shpcnf_retdata->{ShipmentConfirmRequest}{Shipment}{ShipFrom}{Address}{StateProvinceCode}= 'PA';
$shpcnf_retdata->{ShipmentConfirmRequest}{Shipment}{ShipFrom}{EMailAddress}              = 'backend@net-a-porter.com';
$shpcnf_retdata->{ShipmentConfirmRequest}{Shipment}{ShipFrom}{PhoneNumber}               = '';

# now make the request
$net_ups->xml_request($shipment_obj, $shpcnf_retdata, { XMLin => { ForceArray => [ 'PackageResults' ] } } );
ok( exists( $net_ups->xml_response->{ShipmentDigest} ), 'Got back Shipment Digest in response for RETURN' );
cmp_ok( $net_ups->xml_response->{Response}{ResponseStatusCode}, '==', 1, 'Response was Success (1) for RETURN' );
$shpacpt_data   = $net_ups->prepare_shipping_accept_xml;
$net_ups->xml_request($shipment_obj, $shpacpt_data, { XMLin => { ForceArray => [ 'PackageResults' ] } } );
ok( exists( $net_ups->xml_response->{ShipmentResults} ), 'Got back Shipment Results in response for RETURN' );
cmp_ok( $net_ups->xml_response->{Response}{ResponseStatusCode}, '==', 1, 'Response was Success (1) for RETURN' );
isa_ok( $net_ups->xml_response->{ShipmentResults}{PackageResults}, 'ARRAY', 'PackageResults in RETURN Response' );


#
# test the call to '$net_ups->process_xml_request' by sumulating different responses
#      because can't simulate the correct responses by really communicating with UPS API
#
note "TEST calls to 'process_xml_request' by simumating responses";

# use a test library that has extended 'xml_request' to simulate different responses
my $txnu    = Test::XT::Net::UPS->new(
                            {
                                simulate_response   => 'Success',
                                config              => $config,
                                shipment            => $carrier_test->ups_shipment,
                            }
                        );
# set the proxy to what was done above, not important more for completness getting rid of Undefined errors
$txnu->set_proxy( $net_ups->proxy );
_test_process_xml( $txnu, 'Success', $shpcnf_data, 1, 'Success' );
_test_process_xml( $txnu, 'Failure', $shpcnf_data, 0, 'Failure' );
_test_process_xml( $txnu, 'WarningSuccess', $shpcnf_data, 1, 'Warnings that are OK' );
_test_process_xml( $txnu, 'WarningFailure', $shpcnf_data, 0, 'Warnings that are NOT OK' );
_test_process_xml( $txnu, 'Die', $shpcnf_data, 0, 'die-ing' );
_test_process_xml( $txnu, 'Retry', $shpcnf_data, 0, 'Retrying past Max Attempts', ($config->max_retries + 1), $config->max_retries, 'Retry' );
_test_process_xml( $txnu, 'Retry', $shpcnf_data, 0, 'Retrying past Max Wait Time', $config->max_retries, 1, 'Retry', ($config->max_retry_wait_time + 1) );
_test_process_xml( $txnu, 'Retry', $shpcnf_data, 0, 'Retrying With No Wait Time', $config->max_retries, 3, 'Retry', -1 );
_test_process_xml( $txnu, 'Retry', $shpcnf_data, 1, 'Retrying With No Wait Time & Success', 2, 2, 'Success', -1 );
_test_process_xml( $txnu, 'Retry', $shpcnf_data, 1, 'Retrying and Success', $config->max_retries, $config->max_retries, 'Success' );
_test_process_xml( $txnu, 'Retry', $shpcnf_data, 0, 'Retrying and Failure', $config->max_retries, $config->max_retries, 'Failure' );

done_testing;

#-----------------------------------------------------------

# helper function to do repetitive tests for process_xml_request
sub _test_process_xml {
    my $txnu    = shift;
    my $response= shift;
    my $reqdata = shift;
    my $result  = shift;
    my $msg     = shift;

    my $retry           = shift;
    my $expected_retry  = shift || $retry;
    my $give_response   = shift;
    my $seconds         = shift;

    $txnu->simulate_response( $response );
    $txnu->set_test_call_counter( 0 );      # zero out the call counter
    $txnu->test_when_retry( undef );

    if ( defined $retry && $retry > 0 ) {
        $txnu->test_when_retry( {
                        on_attempt      => $retry,
                        give_response   => $give_response,
                        retry_seconds   => ( defined $seconds ? $seconds : ( $txnu->config->max_retry_wait_time - $txnu->config->max_retry_wait_time + 1 ) ),
                    } );
    }

    cmp_ok( $txnu->process_xml_request({
        shipment    => $shipment_obj,
        xml_data    => $reqdata,
    }), '==', $result, "'process_xml_request' result: $result, handles $msg" );
    is_deeply( $txnu->xml_response, $txnu->test_xml_response, "xml response matches" );
    is( $txnu->error, $txnu->test_error, "error matches" );
    if ( defined $txnu->test_when_retry ) {
        cmp_ok( $txnu->test_call_counter, '==', $expected_retry, "number of attempts correct: ".$txnu->test_call_counter );
    }

    return;
}


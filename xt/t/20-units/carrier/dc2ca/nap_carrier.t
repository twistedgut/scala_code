#!/usr/bin/env perl

=head1 NAME

nap.carrier.t - Tests for NAP::Carrier

=head1 DESCRIPTION

#TAGS carrier dhl ups premier loops

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;
use Net::UPS::Address;

use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw( :channel );

# this forces connections to the same DB & forces the
# use of the same config files as the Test Harness
use Test::XTracker::Data;

use XTracker::Config::Local qw< config_var >;

use Test::XTracker::Carrier;

use Data::Dump qw(pp);

my $dc_name = config_var( 'DistributionCentre', 'name' );
note "TESTING ON ".$dc_name;

use_ok('NAP::Carrier');

# these are functions that NAP::Carrier and NAP::Carrier::* should support
my @expected_methods = qw<
    carrier
    classification
    deduce_autoable
    is_autoable
    manifest
    name
    quality_rating
    set_carrier
    set_classification
    set_name
    validate_address
    set_address_validator
    address_validator
>;

# make sure the generic object supports our methods
can_ok('NAP::Carrier', @expected_methods);

# something to give us useful objects/records to test with
my $carrier_test = Test::XTracker::Carrier->new;

# we'll need a schema to pass to new()
my $schema = $carrier_test->schema;

# store the current Carrier Automation Settings per Sales Channels
my $auto_states = $schema->resultset('Public::Channel')->get_carrier_automation_states();

# store them, so we're not forever looking then up in the DB
my $ups_shipment    = $carrier_test->ups_shipment;
my $dhl_shipment    = $carrier_test->dhl_shipment;
my $ups_shipment_id = ( defined $ups_shipment ? $ups_shipment->id : 0 );
my $dhl_shipment_id = ( defined $dhl_shipment ? $dhl_shipment->id : 0 );
my $manifest_id     = $carrier_test->any_manifest->id;
my $shipment_id     = $ups_shipment_id || $dhl_shipment_id;

throws_ok(
    sub { NAP::Carrier->new({shipment_id=>$shipment_id}) },
    qr{Attribute \(operator_id\) is required},
    "calling NAP::Carrier->new with no operator_id should fail"
);

throws_ok(
    sub { NAP::Carrier->new },
    qr{must specify exactly ONE of shipment_id or manifest_id},
    "calling NAP::Carrier->new with no args should fail"
);

# calling NAP::Carrier->new with neither shipment_id/manifest_id should fail
throws_ok(
    sub { NAP::Carrier->new({operator_id=>$APPLICATION_OPERATOR_ID}) },
    qr{must specify exactly ONE of shipment_id or manifest_id},
    "calling NAP::Carrier->new with neither shipment_id/manifest_id should fail"
);

subtest 'calling with shipment_id' => sub {
    my $nc = NAP::Carrier->new({shipment_id => $shipment_id,operator_id=>$APPLICATION_OPERATOR_ID});
    isnt(ref($nc), 'NAP::Carrier', '$new_object is NOT a NAP::Carrier');
    is($nc->shipment_id,$shipment_id,"shipment_id is set correctly");
    # make sure the $nc object supports our methods
    can_ok(ref $nc, @expected_methods);
};

# calling with shipment_id of wrong type should fail
throws_ok(
    sub { NAP::Carrier->new({shipment_id => 'six six seven',operator_id=>$APPLICATION_OPERATOR_ID}) },
    qr{Validation failed for 'Int'.*six six seven},
    "validation error given for shipment_id of wrong type"
);


subtest 'calling with manifest_id' => sub {
    my $nc = NAP::Carrier->new({manifest_id => $manifest_id,operator_id=>$APPLICATION_OPERATOR_ID});
    isnt(ref($nc), 'NAP::Carrier', '$new_object is NOT a NAP::Carrier');
    is($nc->manifest_id,$manifest_id,"manifest_id is set correctly");
    # make sure the $nc object supports our methods
    can_ok(ref $nc, @expected_methods);
};

# call with shipment_id and manifest_id, each with values that (currently)
# return DHL and make sure we have methods/attributes that we expect if things
# have been instantiated "properly"
{
    my @tests = (
        { type => 'shipment', get_id => $carrier_test->dhl_shipment('DHL Express'), derived_name => 'DHL'    , derived_class => 'Express' },
        { type => 'shipment', get_id => $carrier_test->ups_shipment()             , derived_name => 'UPS'    , derived_class => 'UPS'     },
        { type => 'shipment', get_id => $carrier_test->premier_shipment()         , derived_name => 'Premier', derived_class => 'Premier' },
        { type => 'shipment', get_id => $carrier_test->unknown_shipment()         , derived_name => 'Unknown', derived_class => 'Unknown' },
        { type => 'manifest', get_id => $carrier_test->dhl_manifest('DHL Express'), derived_name => 'DHL'    , derived_class => 'Express' },
        { type => 'manifest', get_id => $carrier_test->ups_manifest()             , derived_name => 'UPS'    , derived_class => 'UPS'     },
    );

    foreach my $test (@tests) {
        if ( !defined $test->{get_id} ) {
            note "No '".$test->{type}."' Id for ".$test->{derived_name}."::".$test->{derived_class};
            next;
        }

        my $nc = NAP::Carrier->new(
            {  operator_id => $APPLICATION_OPERATOR_ID, $test->{type}."_id" => $test->{get_id}->id }
        );

        isa_ok($nc, "NAP::Carrier::$test->{derived_name}",
            "correct return type of ::$test->{derived_name} for ".$test->{type});

        is($nc->classification, $test->{derived_class},
            "correct return classification $test->{derived_class}");

        # if we have a manifest_id we should have a manifest
        if (defined $nc->manifest_id) {
            ok(defined($nc->manifest),
                $nc->manifest_id . ' has a defined manifest attribute');
        }
        # if we have a shipment_id we should have a shipment
        elsif (defined $nc->shipment_id) {
            ok(defined($nc->shipment),
                $nc->shipment_id . ' has a defined shipment attribute');
        }

        # test default Address Validator
        is($nc->address_validator, $test->{derived_name}, 'correct default AV for '.$test->{derived_name}.' '.$test->{type});

        # DHL/UPS should have a ->config method
        if ($nc->name =~ m{\A(?:UPS|DHL)\z}) {
            can_ok($nc, qw<config>);
            isa_ok(
                $nc->config,
                'NAP::Carrier::' . $nc->name . '::Config',
                'correct return type of ::' . $nc->name . '->config'
            );
        }
    }
}

#
# do some tests on carrier name and classification (by shipment)
#
# XXX these might change/be wrong in other places, or go missing if
# XXX we ever use a cut down test data set
{
    my $express_shipment = $carrier_test->dhl_shipment('DHL Express');
    my $ups_shipment     = $carrier_test->ups_shipment();
    my $premier_shipment = $carrier_test->premier_shipment();
    my $unknown_shipment = $carrier_test->unknown_shipment();

    my @tests = ();

    if (defined $express_shipment) {
        push @tests, {
            shipment_id     =>$express_shipment->id,
            derived_name    =>'DHL',
            derived_class   =>'Express',
        };
    }
    if (defined $ups_shipment) {
        push @tests, {
            shipment_id     =>$ups_shipment->id,
            derived_name    =>'UPS',
            derived_class   =>'UPS',
        };
    }
    if (defined $premier_shipment) {
        push @tests, {
            shipment_id     => $premier_shipment->id,
            derived_name    =>'Premier',
            derived_class   =>'Premier'
        };
    }
    if (defined $unknown_shipment) {
        push @tests, {
            shipment_id     => $unknown_shipment->id,
            derived_name    =>'Unknown',
            derived_class   =>'Unknown'
        };
    }

    foreach my $test (@tests) {
        my $nc = NAP::Carrier->new(
            { shipment_id => $test->{shipment_id}, operator_id => $APPLICATION_OPERATOR_ID }
        );
        is($nc->shipment_id, $test->{shipment_id},
            "shipment_id ok for $test->{shipment_id}");
        is($nc->name, $test->{derived_name},
            "carrier name ok for $test->{derived_name}");
        is($nc->classification, $test->{derived_class},
            "carrier classification ok for $test->{derived_class}");
        isa_ok($nc, "NAP::Carrier::$test->{derived_name}",
            "correct return type of ::$test->{derived_name}");
    }
}

#
# "unknown" & "premier" carrier should *always* be is_autoable()==false
#
{
    my $unknown_shipment = $carrier_test->unknown_shipment;
    my $nc = NAP::Carrier->new(
        {shipment_id=>$unknown_shipment->id,operator_id=>$APPLICATION_OPERATOR_ID}
    );
    isa_ok($nc, 'NAP::Carrier::Unknown', 'correct return type of ::Unknown');
    is($nc->is_autoable, 0, 'NAP::Carrier::Unknown is not autoable');
}

{
    my $premier_shipment = $carrier_test->premier_shipment;
    my $nc = NAP::Carrier->new(
        {shipment_id=>$premier_shipment->id,operator_id=>$APPLICATION_OPERATOR_ID}
    );
    isa_ok($nc, 'NAP::Carrier::Premier', 'correct return type of ::Premier');
    is($nc->is_autoable, 0, 'NAP::Carrier::Premier is not autoable');
}

#
# Do some tests with manifests to check txt/pdf links are ok amongst others
#
{
    my @tests = (
        { carrier => 'UPS',
            isa_check     => '::UPS',
            name          => 'UPS',
            classification=> 'UPS',
            txt_link_like => qr{\A/manifest/txt/.+\.csv\z},
            pdf_link_like => qr{\A/manifest/pdf/.+\.pdf\z} },
        { carrier => 'DHL Express',
            isa_check     => '::DHL',
            name          => 'DHL',
            classification=> 'Express',
            txt_link_like => ( config_var('UPS', 'enabled')
                ? qr{\A/manifest/txt/.+\.csv\z}
                : qr{\A/manifest/txt/.+\.txt\z}
            ),
            pdf_link_like => qr{\A/manifest/pdf/.+\.pdf\z} },
    );
    foreach my $test (@tests) {
        # grab a record of the desired carrier type
        my $record = $schema
            ->resultset('Public::Manifest')
            ->search(
                { 'carrier.name'=>$test->{carrier},
                  'cut_off'=>{ '>' => '2009-05-01 00:00:00' } }, # clear before we went channelised
                { join=>[qw<carrier>], rows=>1 }
            )
            ->single;

        if (not defined $record) {
            diag "no matching manifest records found for $test->{carrier}";
            next;
        }

        # make sure our record has the correct carrier (#paranoid)
        is($record->carrier->name,$test->{carrier},
            "found a manifest record for $test->{carrier}");

        # create a new NAP::Carrier for the manifest
        my $nc = NAP::Carrier->new({
            manifest_id=>$record->id, operator_id=>$APPLICATION_OPERATOR_ID
        });

        # another check to confirm that we've got the correct carrier
        is($nc->carrier,$test->{carrier},
            "NAP::Carrier has correct carrier, $test->{carrier}");
        is($nc->manifest_id, $record->id,
            "manifest_id ok for ".$record->id);
        is($nc->name, $test->{name},
            "carrier name ok for ".$test->{name});
        is($nc->classification, $test->{classification},
            "carrier classification ok for ".$test->{classification});

        isa_ok($nc, 'NAP::Carrier'.$test->{isa_check}, 'correct return type of '.$test->{isa_check});
        can_ok($nc, qw<config>);
        isa_ok($nc->config, 'NAP::Carrier'.$test->{isa_check}.'::Config', 'correct return type of '.$test->{isa_check}.'->config');
        isa_ok($nc->manifest, 'XTracker::Schema::Result::Public::Manifest');
        is($nc->classification, $test->{classification}, 'Carrier Classification is '.$test->{classification} );

        # make sure the text links "look ok"
        like(
            $nc->manifest_txt_link,
            $test->{txt_link_like},
            "text link looks ok for $test->{carrier}"
        );
        # make sure the pdf links "look ok"
        like(
            $nc->manifest_pdf_link,
            $test->{pdf_link_like},
            "pdf link looks ok for $test->{carrier}"
        );
    }
}

#
##
### UPS tests
##
#
SKIP: {
    skip "Can Only Test UPS Specific Tests with UPS enabled", unless config_var('UPS', 'enabled');

    my ($av_result);
    my $ups_shipment    = $carrier_test->ups_shipment;
    my $premier_shipment= $carrier_test->premier_shipment;
    my $unknown_shipment= $carrier_test->unknown_shipment;

    my $ncu = NAP::Carrier->new(
        {shipment_id=>$ups_shipment->id,operator_id=>$APPLICATION_OPERATOR_ID}
    );
    isa_ok($ncu, 'NAP::Carrier::UPS', 'correct return type of ::UPS');
    can_ok($ncu, qw<config>);
    isa_ok($ncu->config, 'NAP::Carrier::UPS::Config', 'correct return type of ::UPS->config');

    my $ncp = NAP::Carrier->new(
        {shipment_id=>$premier_shipment->id,operator_id=>$APPLICATION_OPERATOR_ID}
    );
    isa_ok($ncp, 'NAP::Carrier::Premier', 'correct return type of ::Premier');

    my $nck = NAP::Carrier->new(
        {shipment_id=>$unknown_shipment->id,operator_id=>$APPLICATION_OPERATOR_ID}
    );
    isa_ok($nck, 'NAP::Carrier::Unknown', 'correct return type of ::Unknown');

    # as we have a valid NAP::Carrier, we should be able to verify some
    # configuration values/methods
    can_ok($ncu->config, qw<
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
    >);

    # address validation

    # UPS should be set as the validator (by default) for UPS shipment
    is($ncu->address_validator, 'UPS', 'correct default AV for UPS shipment');

    # change it
    $ncu->set_address_validator('DHL');
    is( $ncu->address_validator, 'DHL', 'correct over-ridden AV for UPS shipment' );

    # change it back
    $ncu->set_address_validator('UPS');
    is($ncu->address_validator, 'UPS', 'and put back default AV for UPS shipment');

    use Test::XTracker::Mock::Net::UPS;
    my $mock_object = Test::XTracker::Mock::Net::UPS->new(
            addresses => [
                {length => 1, postal_code => 10001, city => 'NEW YORK', state => 'NY'},
                {nowhere => 1},
                {length => 1, postal_code => 10001, city => 'NEW YORK', state => 'NY'},
                {nowhere => 1},
                {length => 1, postal_code => 10001, city => 'NEW YORK', state => 'NY'},
                {length => 1, postal_code => 10001, city => 'NEW YORK', state => 'NY'},
                {length => 1, postal_code => 10001, city => 'NEW YORK', state => 'NY'},
                {length => 1, postal_code => 10001, city => 'NEW YORK', state => 'NY'},
                {nowhere => 1},
                {nowhere => 1},
            ],
        )
        ->mock('validate_address');

    # test with a known good NY zipcode; Adams, NY (13605)
    # call Net::UPS instead of XT::Net::UPS
    $av_result = $ncu->net_ups->validate_address(13605);
    ok($av_result->[0]->is_close_match, 'close match for NY zipcode');

    # test with a rubbish zipcode
    # call Net::UPS instead of XT::Net::UPS
    $av_result = $ncu->net_ups->validate_address(99999);
    is($av_result,'No Address Candidate Found',q{no results for rubbish zipcode});

    # build a Net::UPS::Address (as per module's perldoc) and test that
    my $address = Net::UPS::Address->new();
    $address->city("Pittsburgh");
    $address->state("PA");
    $address->postal_code("15228");
    $address->country_code("US");
    $address->is_residential(1);
    # call Net::UPS instead of XT::Net::UPS
    $av_result = $ncu->net_ups->validate_address($address);
    ok($av_result->[0]->is_match, 'exact match for US Net::UPS::Address object');

    $schema->txn_dont( sub {
        # Update shipment's address to do tests

        # get channel for UPS shipment
        my $channel = $ups_shipment->shipping_account->channel;

        # create a dummy log entry to test for changes later
        $schema->resultset('Public::LogShipmentRtcbState')->create( {
            shipment_id => $ups_shipment->id,
            new_state   => 0,
            operator_id => $APPLICATION_OPERATOR_ID,
            reason_for_change => 'TEST',
        } );

        # set up a resultset to check to log changes to the rtcb field
        my $rtcb_log = $schema->resultset('Public::LogShipmentRtcbState')->search(
            { shipment_id => $ups_shipment->id, },
            { order_by    => 'id DESC', }
        );
        my $tmp_log = $rtcb_log->first;

        # Turn on Carrier Automation State for Shipment's Sales Channel
        Test::XTracker::Data->set_carrier_automation_state( $channel->id, 'On' );

        # lets try a rubbish address
        $ups_shipment->shipment_address->update( {
            towncity    => "",
            county      => "",
            postcode    => "99999",
            country     => "United States",
        } );
        $address    = $ncu->prepare_ups_address;
        isa_ok( $address, "Net::UPS::Address", "Prepared UPS Address using Net::UPS::Address" );
        $av_result  = $ncu->validate_address;
        $ups_shipment->discard_changes;
        cmp_ok( $av_result, "==", 0, "NAP::Carrier failed using rubbish address" );
        cmp_ok( $ups_shipment->real_time_carrier_booking, "==", 1, "NAP::Carrier RTCB field TRUE" );
        is( $ups_shipment->destination_code, undef, 'DHL Destination Code IS Empty' );      # DHL Destination Code should always be empty for UPS
        # reset the log resultset to get any new entries
        $rtcb_log->reset;
        cmp_ok( $rtcb_log->first->id, ">", $tmp_log->id, "RTCB Recent Log has changed" );
        like( $rtcb_log->first->reason_for_change, qr/^AUTO: Changed After 'is_autoable' TEST via Address Validation Check/, "RTCB Recent Log Reason is correct" );
        $tmp_log    = $rtcb_log->first;
        # try a good address
        $ups_shipment->shipment_address->update( {
            towncity    => "Long Island City",
            county      => "NY",
            postcode    => "11101",
            country     => "United States",
        } );
        $av_result  = $ncu->validate_address;
        $ups_shipment->discard_changes;
        cmp_ok( $av_result, "==", 1, "NAP::Carrier succeeded on good address" );
        cmp_ok( $ups_shipment->real_time_carrier_booking, "==", 1, "NAP::Carrier RTCB field now TRUE" );
        cmp_ok( $ups_shipment->av_quality_rating, ">", $ncu->config->quality_rating_threshold, "NAP::Carrier av_quality_rating field set >= threshold (".$ncu->config->quality_rating_threshold."): ".$ups_shipment->av_quality_rating );
        is( $ups_shipment->destination_code, undef, 'DHL Destination Code IS Empty' );      # DHL Destination Code should always be empty for UPS
        # reset the log resultset to get any new entries
        $rtcb_log->reset;
        cmp_ok( $rtcb_log->first->id, "==", $tmp_log->id, "RTCB Recent Log has not changed" );
        is( $rtcb_log->first->reason_for_change, "AUTO: Changed After 'is_autoable' TEST via Address Validation Check", "RTCB Recent Log Reason is correct" );
        cmp_ok( $rtcb_log->first->new_state, "==", 1, "RTCB Recent Log State is TRUE" );
        $tmp_log    = $rtcb_log->first;

        # try another good address
        $ups_shipment->shipment_address->update( {
            towncity    => "Pittsburgh",
            county      => "PA",
            postcode    => "15228",
            country     => "United States",
        } );
        $av_result  = $ncu->validate_address;
        $ups_shipment->discard_changes;
        cmp_ok( $av_result, "==", 1, "NAP::Carrier succeeded on another good address" );
        cmp_ok( $ups_shipment->real_time_carrier_booking, "==", 1, "NAP::Carrier RTCB field still TRUE" );
        cmp_ok( $ups_shipment->av_quality_rating, ">", $ncu->config->quality_rating_threshold, "NAP::Carrier av_quality_rating field set >= threshold (".$ncu->config->quality_rating_threshold."): ".$ups_shipment->av_quality_rating );
        is( $ups_shipment->destination_code, undef, 'DHL Destination Code IS Empty' );      # DHL Destination Code should always be empty for UPS
        # reset the log resultset to get any new entries
        $rtcb_log->reset;
        cmp_ok( $rtcb_log->first->id, "==", $tmp_log->id, "RTCB Recent Log has not changed" );
        $tmp_log    = $rtcb_log->first;

        # try good address again but with Carrier Automation State as 'Off'
        Test::XTracker::Data->set_carrier_automation_state( $channel->id, 'Off' );
        $av_result  = $ncu->validate_address;
        $ups_shipment->discard_changes;
        cmp_ok( $av_result, "==", 0, "NAP::Carrier failed using Good address but with Automation State set to 'Off'" );
        cmp_ok( $ups_shipment->real_time_carrier_booking, "==", 0, "NAP::Carrier RTCB field now set back to FALSE" );
        is( $ups_shipment->destination_code, undef, 'DHL Destination Code IS Empty' );      # DHL Destination Code should always be empty for UPS
        # reset the log resultset to get any new entries
        $rtcb_log->reset;
        cmp_ok( $rtcb_log->first->id, ">", $tmp_log->id, "RTCB Recent Log has changed" );
        cmp_ok( $rtcb_log->first->new_state, "==", 0, "RTCB Recent Log State is FALSE" );
        like( $rtcb_log->first->reason_for_change, qr/^STATE: Carrier Automation State is 'Off'/, "RTCB Recent Log Reason is correct" );
        $tmp_log    = $rtcb_log->first;

        # try again and same result but a new log SHOULD have been created
        $av_result  = $ncu->validate_address;
        $ups_shipment->discard_changes;
        cmp_ok( $ups_shipment->real_time_carrier_booking, "==", 0, "NAP::Carrier RTCB field still FALSE" );
        $rtcb_log->reset;
        cmp_ok( $rtcb_log->first->id, ">", $tmp_log->id, "RTCB Recent Log has changed" );
        like( $rtcb_log->first->reason_for_change, qr/^STATE: Carrier Automation State is 'Off'/, "RTCB Recent Log Reason is correct" );
        $tmp_log    = $rtcb_log->first;

        # try bad address again but with Carrier Automation State as 'Import_Off_Only'
        Test::XTracker::Data->set_carrier_automation_state( $channel->id, 'Import_Off_Only' );
        $av_result  = $ncu->validate_address;
        $ups_shipment->discard_changes;
        cmp_ok( $av_result, "==", 0, "NAP::Carrier failed on bad address with Automation State as 'Import_Off_Only'" );
        cmp_ok( $ups_shipment->real_time_carrier_booking, "==", 1, "NAP::Carrier RTCB field set to TRUE" );
        like( $ups_shipment->av_quality_rating, qr/^No Address Candidate Found/, "Invalid address");
        is( $ups_shipment->destination_code, undef, 'DHL Destination Code IS Empty' );      # DHL Destination Code should always be empty for UPS
        # reset the log resultset to get any new entries
        $rtcb_log->reset;
        cmp_ok( $rtcb_log->first->id, ">", $tmp_log->id, "RTCB Recent Log has changed" );
        cmp_ok( $rtcb_log->first->new_state, "==", 1, "RTCB Recent Log State is TRUE" );
        is( $rtcb_log->first->reason_for_change, "AUTO: Changed After 'is_autoable' TEST via Address Validation Check", "RTCB Recent Log Reason is correct" );
        $tmp_log    = $rtcb_log->first;

        # try good address again with Carrier Automation State as 'Import_Off_Only' but pass context_is as 'order_importer' to address validator
        $av_result  = $ncu->validate_address( { context_is => 'order_importer' } );
        $ups_shipment->discard_changes;
        cmp_ok( $av_result, "==", 0, "NAP::Carrier failed using Good address but with Automation State set to 'Import_Off_Only' and Address Validator called with context_is as 'order_importer'" );
        cmp_ok( $ups_shipment->real_time_carrier_booking, "==", 0, "NAP::Carrier RTCB field now set back to FALSE" );
        is( $ups_shipment->destination_code, undef, 'DHL Destination Code IS Empty' );      # DHL Destination Code should always be empty for UPS
        # reset the log resultset to get any new entries
        $rtcb_log->reset;
        cmp_ok( $rtcb_log->first->id, ">", $tmp_log->id, "RTCB Recent Log has changed" );
        cmp_ok( $rtcb_log->first->new_state, "==", 0, "RTCB Recent Log State is FALSE" );
        like( $rtcb_log->first->reason_for_change, qr/^STATE: Carrier Automation State is 'Import_Off_Only'/, "RTCB Recent Log Reason is correct" );
        $tmp_log    = $rtcb_log->first;

        # try again and same result but a new log SHOULD have been created
        $av_result  = $ncu->validate_address( { context_is => 'order_importer' } );
        $ups_shipment->discard_changes;
        cmp_ok( $ups_shipment->real_time_carrier_booking, "==", 0, "NAP::Carrier RTCB field still FALSE" );
        $rtcb_log->reset;
        cmp_ok( $rtcb_log->first->id, ">", $tmp_log->id, "RTCB Recent Log has changed" );
        like( $rtcb_log->first->reason_for_change, qr/^STATE: Carrier Automation State is 'Import_Off_Only'/, "RTCB Recent Log Reason is correct" );
        $tmp_log    = $rtcb_log->first;

        # try a bad address again with Automation State set to 'On' and context set to 'order_importer' and Shipment should be Autoable
        Test::XTracker::Data->set_carrier_automation_state( $channel->id, 'On' );
        $av_result  = $ncu->validate_address( { context_is => 'order_importer' } );
        $ups_shipment->discard_changes;
        cmp_ok( $av_result, "==", 0, "NAP::Carrier failed on bad address with Automation State back to 'On' and Address Validator called with context_is as 'order_importer'" );
        cmp_ok( $ups_shipment->real_time_carrier_booking, "==", 1, "NAP::Carrier RTCB field now TRUE" );
        like( $ups_shipment->av_quality_rating, qr/^No Address Candidate Found/, "Invalid address");
        is( $ups_shipment->destination_code, undef, 'DHL Destination Code IS Empty' );      # DHL Destination Code should always be empty for UPS
        # reset the log resultset to get any new entries
        $rtcb_log->reset;
        cmp_ok( $rtcb_log->first->id, ">", $tmp_log->id, "RTCB Recent Log has changed" );
        is( $rtcb_log->first->reason_for_change, "AUTO: Changed After 'is_autoable' TEST via Address Validation Check", "RTCB Recent Log Reason is correct" );
        cmp_ok( $rtcb_log->first->new_state, "==", 1, "RTCB Recent Log State is TRUE" );
        $tmp_log    = $rtcb_log->first;

        # try a rubbish address again
        $ups_shipment->shipment_address->update( {
            towncity    => "",
            county      => "",
            postcode    => "99999",
            country     => "United States",
        } );
        $av_result  = $ncu->validate_address;
        $ups_shipment->discard_changes;
        # the address above is not used. Address from Mock class is used, and its a valid one
        cmp_ok( $av_result, "==", 1, "NAP::Carrier passed using good address again" );
        cmp_ok( $ups_shipment->real_time_carrier_booking, "==", 1, "NAP::Carrier RTCB field now set back to TRUE" );
        cmp_ok( $ups_shipment->av_quality_rating, ">", $ncu->config->quality_rating_threshold, "NAP::Carrier av_quality_rating field set above threshold (".$ncu->config->quality_rating_threshold."): ".$ups_shipment->av_quality_rating );
        is( $ups_shipment->destination_code, undef, 'DHL Destination Code IS Empty' );      # DHL Destination Code should always be empty for UPS
        # reset the log resultset to get any new entries
        $rtcb_log->reset;
        cmp_ok( $rtcb_log->first->id, "==", $tmp_log->id, "RTCB Recent Log has not changed" );
        cmp_ok( $rtcb_log->first->new_state, "==", 1, "RTCB Recent Log State is TRUE" );
        like( $rtcb_log->first->reason_for_change, qr/^AUTO: Changed After 'is_autoable' TEST via Address Validation Check/, "RTCB Recent Log Reason is correct" );

        # premier shipment should not become autoable after AV
        # in fact AV should do nothing for Premier Shipments
        $ncp->deduce_autoable;
        $premier_shipment->discard_changes;
        cmp_ok( $premier_shipment->real_time_carrier_booking, '==', 0, 'Premier Shipment is NOT Automated' );
        # use a good address
        $premier_shipment->shipment_address->update( {
            towncity    => "Pittsburgh",
            county      => "PA",
            postcode    => "15228",
            country     => "United States",
        } );
        $av_result  = $ncp->validate_address;
        $premier_shipment->discard_changes;
        is( $av_result, 1, "Premier Shipment has valid address" );
        cmp_ok( $premier_shipment->real_time_carrier_booking, "==", 0, 'Premier Shipment is still NOT Automated' );
        like( $premier_shipment->av_quality_rating , qr/^$/, "Premier Shipment doesn't have an av_quality_rating set" );
        is( $premier_shipment->destination_code, undef, 'DHL Destination Code IS Empty' );      # DHL Destination Code should always be empty for Premier in DC2

        # Note that apparently 'Unknown' shipments are 'Premier' shipments.
        # unknown shipment should not become autoable after AV
        # in fact AV should do nothing for Unknown Shipments
        $nck->deduce_autoable;
        $unknown_shipment->discard_changes;
        cmp_ok( $unknown_shipment->real_time_carrier_booking, '==', 0, 'Unknown Shipment is NOT Automated' );
        # use a good address
        $unknown_shipment->shipment_address->update( {
            towncity    => "Pittsburgh",
            county      => "PA",
            postcode    => "15228",
            country     => "United States",
        } );
        $av_result  = $nck->validate_address;
        $unknown_shipment->discard_changes;
        is( $av_result, 1, "Unknown Shipment has valid address" );
        cmp_ok( $unknown_shipment->real_time_carrier_booking, "==", 0, 'Unknown Shipment is still NOT Automated' );
        like( $unknown_shipment->av_quality_rating , qr/^$/, "Unknown Shipment doesn't have an av_quality_rating set" );
        is( $unknown_shipment->destination_code, undef, 'DHL Destination Code IS Empty' );      # DHL Destination Code should always be empty for Unknown in DC2
    } );
}

#
##
### DHL tests
##
#
SKIP: {
    skip "Can't Test DHL Specific Tests on DC2 Environment",1    if ( $dc_name eq "DC2" );

    my $dhl_shipment    = $carrier_test->dhl_shipment;
    my $premier_shipment= $carrier_test->premier_shipment;
    my $unknown_shipment= $carrier_test->unknown_shipment;

    my $ncd = NAP::Carrier->new(
        {shipment_id=>$dhl_shipment->id,operator_id=>$APPLICATION_OPERATOR_ID}
    );
    isa_ok($ncd, 'NAP::Carrier::DHL', 'correct return type of ::DHL');
    can_ok($ncd, qw<config>);
    isa_ok($ncd->config, 'NAP::Carrier::DHL::Config', 'correct return type of ::DHL->config');

    my $ncp = NAP::Carrier->new(
        {shipment_id=>$premier_shipment->id,operator_id=>$APPLICATION_OPERATOR_ID}
    );
    isa_ok($ncp, 'NAP::Carrier::Premier', 'correct return type of ::Premier');

    my $nck = NAP::Carrier->new(
        {shipment_id=>$unknown_shipment->id,operator_id=>$APPLICATION_OPERATOR_ID}
    );
    isa_ok($nck, 'NAP::Carrier::Unknown', 'correct return type of ::Unknown');

    # DHL address validation
    # mimic the block from Order/Actions/UpdateAddress.pm
    $ncd->set_carrier(undef); # so we trigger the if{}
    if (not defined $ncd->carrier) {
        $ncd->set_address_validator('DHL');
    }
    # we should fall-back to DHL
    is($ncd->address_validator, 'DHL', 'correct default AV for DHL shipment');

    $dhl_shipment->discard_changes;

    $schema->txn_dont( sub {

        # DHL Shipments shouldn't become Autoable
        $ncp->deduce_autoable;
        $dhl_shipment->discard_changes;
        cmp_ok( $dhl_shipment->real_time_carrier_booking, '==', 0, 'DHL Shipment is NOT Automated' );

        # clear out all destination codes for the shipments with the same address for tests
        $schema->resultset('Public::Shipment')->search( { shipment_address_id => $dhl_shipment->shipment_address_id } )
                                                ->update( { destination_code => '' } );

        # Shipment should never become Automated when a DHL shipment
        cmp_ok( $dhl_shipment->is_carrier_automated, '==', 0, 'Shipment is NOT Automated' );

        # use a bad address
        $dhl_shipment->shipment_address->update( {
            towncity        => '',
            county          => '',
            postcode        => '',
            #country         => ''
        } );

        $ncd->validate_address;
        $dhl_shipment->discard_changes;
        is( $dhl_shipment->destination_code, '', 'DHL Destination Code is Empty' );
        # Shipment should never become Automated when a DHL shipment
        cmp_ok( $dhl_shipment->is_carrier_automated, '==', 0, 'Shipment is NOT Automated' );

        # use a good address
        $dhl_shipment->shipment_address->update( {
            towncity    => 'Glasgow',
            county      => 'Lanarkshire',
            postcode    => 'G2 3QA',
            country     => 'United Kingdom'
        } );
        $ncd->validate_address;
        $dhl_shipment->discard_changes;
        is( $dhl_shipment->destination_code, 'GLA', 'DHL Destination Code is GLA' );
        # Shipment should never become Automated when a DHL shipment
        cmp_ok( $dhl_shipment->is_carrier_automated, '==', 0, 'Shipment is NOT Automated' );

        # use a foreign address
        $dhl_shipment->shipment_address->update( {
            towncity    => 'Pittsburgh',
            county      => 'PA',
            postcode    => '15228',
            country     => 'United States'
        } );
        $ncd->validate_address;
        $dhl_shipment->discard_changes;
        is( $dhl_shipment->destination_code, 'PIT', 'DHL Destination Code is PIT' );
        # Shipment should never become Automated when a DHL shipment
        cmp_ok( $dhl_shipment->is_carrier_automated, '==', 0, 'Shipment is NOT Automated' );

        # Premier shipments should go through DHL's usual AV

        # Premier shipments shouldn't be Autoable
        $ncp->deduce_autoable;
        $premier_shipment->discard_changes;
        cmp_ok( $premier_shipment->real_time_carrier_booking, '==', 0, 'Premier Shipment is NOT Automated' );

        # use a good address
        $premier_shipment->shipment_address->update( {
            towncity    => "Pittsburgh",
            county      => "PA",
            postcode    => "15228",
            country     => "United States",
        } );
        # Premier shipments used to do DHL address validation - they shouldn't.
        # As we construct our data 'incorrectly' (on shipment creation they are
        # assigned a default destination_code of 'LHR'), and as
        # destination_code will be dropped, let's just check it's unchanged
        {
        my $expected_destination_code = $premier_shipment->destination_code;
        $ncp->validate_address;
        $premier_shipment->discard_changes;
        is( $premier_shipment->destination_code, $expected_destination_code,
            'Premier Shipment DHL Destination Code is unchanged' );
        # Shipment should never become Automated when a Premier shipment
        cmp_ok( $dhl_shipment->is_carrier_automated, '==', 0, 'Shipment is NOT Automated' );
        }

        # Unknown shipments shouldn't be Autoable
        $nck->deduce_autoable;
        $unknown_shipment->discard_changes;
        cmp_ok( $unknown_shipment->real_time_carrier_booking, '==', 0, 'Unknown Shipment is NOT Automated' );

        # use a good address
        $unknown_shipment->shipment_address->update( {
            towncity    => "Pittsburgh",
            county      => "PA",
            postcode    => "15228",
            country     => "United States",
        } );
        # Unknown shipments are a mystery to me as how they differ from Premier
        # shipments - but we keep the logic the same (i.e. we check it doesn't
        # change)
        {
        my $expected_destination_code = $unknown_shipment->destination_code;
        $nck->validate_address;
        $unknown_shipment->discard_changes;
        is( $unknown_shipment->destination_code, $expected_destination_code,
            'Unknown Shipment DHL Destination Code is unchanged' );
        # Shipment should never become Automated when a Unknown shipment
        cmp_ok( $dhl_shipment->is_carrier_automated, '==', 0, 'Shipment is NOT Automated' );
        }
    } );
}

# restore the current Carrier Automation Settings per Sales Channel
Test::XTracker::Data->restore_carrier_automation_state( $auto_states );

done_testing;

package Test::NAP::Carrier::DHL;

use NAP::policy "tt", "test";

use parent 'NAP::Test::Class';
use Test::MockModule;
use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( $APPLICATION_OPERATOR_ID );
use XTracker::DBEncode              qw( decode_db );
use XTracker::DHL::RoutingRequest   qw( get_dhl_destination_code );
use Test::MockModule;
use Test::XTracker::Data;
use Test::XTracker::Mock::DHL::XMLRequest;
use Encode                          qw( decode :fallback_all );
use XML::LibXML;
use XTracker::DHL::XMLDocument;
use XTracker::DHL::XMLRequest;
use XTracker::Schema::Result::Public::Shipment;
use NAP::Carrier;
use XTracker::Constants::FromDB qw(
    :shipment_hold_reason
    :shipment_status
    :shipment_type
    );
use Test::MockObject::Extends;

sub startup : Test(startup => no_plan) {
    my $self = shift;

    ok($self->dbh, "I have a DB Handle");
    ok($self->schema, "I have a Schema");

}

sub setup : Test( setup => no_plan ) {
    my $self    = shift;

    my $schema = $self->schema;
    $self->{current_time} = $schema->db_now();

    my $address = Test::XTracker::Data->create_order_address_in('current_dc');

    my @channels = Test::XTracker::Data->get_enabled_channels->all;

    my $order_data = create_an_order( {
        channel_id => $channels[0]->id,
        address => $address,
    } );

    $self->{shipment} = $order_data->shipments->first;

    $self->{dhl_label_type} =  'dhl_routing';
}


sub a_test_dhl_validate_address_should_hold_on_non_ascii_non_latin1 : Tests {
    my $self = shift;

    my $address = Test::XTracker::Data->create_order_address_in('NonASCIICharacters');

    # set up the mocked call to DHL to retrieve shipment validate XML response
    my $dhl_type = $self->{dhl_label_type};
    my $mock_data = Test::XTracker::Mock::DHL::XMLRequest->new(
        data => [
            { dhl_label => $dhl_type },
        ]
    );

    my $mocked = Test::MockModule->new('XTracker::DHL::XMLRequest');
    $mocked->mock( send_xml_request => sub { $mock_data->$dhl_type } );

    my @channels = Test::XTracker::Data->get_enabled_channels->all;

    my $order_data = Test::XTracker::Data::Order->create_new_order( {
        channel => $channels[0],
        address => $address,
    } );

    my $shipment = $order_data->{shipment_object};

    note( "Shipment id is ".$shipment->id );

    my $carrier = NAP::Carrier->new( {
        schema => $self->schema,
        shipment_id => $shipment->id,
        operator_id => $APPLICATION_OPERATOR_ID,
    } );

    ok( $carrier, "I have a carrier object");

    my $valid = $carrier->validate_address;

    ok( $shipment->shipment_holds->search( {
        shipment_hold_reason_id => $SHIPMENT_HOLD_REASON__INVALID_CHARACTERS
        } )->first,
        "Placed on hold due to invalid address"
    );
}

sub a_test_dhl_does_not_hold_shipment_if_only_address_line_3_non_latin : Tests {
    my $self = shift;

    my $address = Test::XTracker::Data->create_order_address_in('LondonPremier');
    $address->update( { address_line_3 => "我能吞下玻璃而不傷身體。" } );

    # set up the mocked call to DHL to retrieve shipment validate XML response
    my $dhl_type = $self->{dhl_label_type};
    my $mock_data = Test::XTracker::Mock::DHL::XMLRequest->new(
        data => [
            { dhl_label => $dhl_type },
        ]
    );

    my $mocked = Test::MockModule->new('XTracker::DHL::XMLRequest');
    $mocked->mock( send_xml_request => sub { $mock_data->$dhl_type } );

    my @channels = Test::XTracker::Data->get_enabled_channels->all;

    my $order_data = create_an_order( {
        channel_id => $channels[0]->id,
        address => $address,
    } );

    my $shipment = $order_data->shipments->first;

    note( "Shipment id is ".$shipment->id );

    my $carrier = NAP::Carrier->new( {
        schema => $self->schema,
        shipment_id => $shipment->id,
        operator_id => $APPLICATION_OPERATOR_ID,
    } );

    ok( $carrier, "I have a carrier object");

    my $valid = $carrier->validate_address;

    ok( $shipment->shipment_address->address_line_3 eq "我能吞下玻璃而不傷身體。",
        "The shipping address has chinese characters in address_line_3" );

    ok( ! $shipment->is_held, "The shipment is not on hold" );
}

sub a_test_to_parse_xml_error_response : Tests {
    my $self = shift;

    my $response = q|<?xml version="1.0" encoding="UTF-8"?><res:ErrorResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com err-res.xsd'>
    <Response>
        <ServiceHeader>
            <MessageTime>2013-02-27T09:56:16+00:00</MessageTime>
        </ServiceHeader>
        <Status>
            <ActionStatus>Error</ActionStatus>
            <Condition>
                <ConditionCode>111</ConditionCode>
                <ConditionData>Error in parsing request XML:An invalid
                    XML character (Unicode: 0xfc) was found in the
                    element content of the document.</ConditionData>
            </Condition>
        </Status>
    </Response></res:ErrorResponse>|;

    dies_ok( sub {
            XTracker::DHL::XMLDocument::parse_xml_response($response)
        }, "Dies if given unvalid XML" );

    eval {
        XTracker::DHL::XMLDocument::parse_xml_response($response);
    };
    my $error;
    $error = $@ if $@;
    ok ( $error, "An exception was raised");
    my $expected = {
        111 => "Error in parsing request XML:An invalid XML character (Unicode: 0xfc) was found in the element content of the document.",
    };
    is_deeply( $error, $expected,
        "Returned error is hashref with expected keys/values");

    $response = q|<?xml version="1.0" encoding="UTF-8"?><res:RoutingErrorResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com routing-err-res.xsd'>
    <Response>
        <ServiceHeader>
            <MessageTime>2013-02-27T11:14:10+00:00</MessageTime><MessageReference>1222333444566677777778888899999</MessageReference>
            <SiteID>NetAPorter</SiteID>
        </ServiceHeader>
        <Status>
            <ActionStatus/>
            <Condition>
                <ConditionCode>RT0006</ConditionCode>
                <ConditionData> The postal code provided by the user is invalid.</ConditionData>
            </Condition>
            <Condition>
                <ConditionCode>RT0008</ConditionCode>
                <ConditionData> The city name provided by the user does
                    not exist in the country.</ConditionData>
                </Condition>
                <Condition>
                    <ConditionCode>RT0004</ConditionCode>
                    <ConditionData> The search for the service area
                        information has failed.</ConditionData>
                    </Condition>
                </Status>
            </Response></res:RoutingErrorResponse>|;

    dies_ok( sub {
            XTracker::DHL::XMLDocument::parse_xml_response($response)
        }, "Dies OK when provided invalid data" );

    {
        local $@;

        eval {
            XTracker::DHL::XMLDocument::parse_xml_response($response);
        };
        my $error;
        $error = $@ if $@;
        ok ( $error, "An exception was raised");
        my $expected = {
            RT0006 => "The postal code provided by the user is invalid.",
            RT0008 => "The city name provided by the user does not exist in the country.",
            RT0004 => "The search for the service area information has failed.",
        };
        is_deeply( $error, $expected,
            "Returned error is hashref with expected keys/values");
    }
}

sub y_test_dhl_error_messages_correctly_logged : Tests { SKIP: {
    # This test needs to run towards the end as it redefines things needed by other tests
    my $self = shift;

    my $shipment = $self->{shipment};

    my $mocked_xml_request = Test::MockModule->new('XTracker::DHL::XMLRequest');
    $mocked_xml_request->mock ('send_xml_request', sub {
        return q|<?xml version="1.0" encoding="UTF-8"?><res:RoutingErrorResponse xmlns:res='http://www.dhl.com' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:schemaLocation= 'http://www.dhl.com routing-err-res.xsd'>
    <Response>
        <ServiceHeader>
            <MessageTime>2013-02-27T11:14:10+00:00</MessageTime><MessageReference>1222333444566677777778888899999</MessageReference>
            <SiteID>NetAPorter</SiteID>
        </ServiceHeader>
        <Status>
            <ActionStatus/>
            <Condition>
                <ConditionCode>RT0006</ConditionCode>
                <ConditionData> The postal code provided by the user is invalid.</ConditionData>
            </Condition>
            <Condition>
                <ConditionCode>RT0008</ConditionCode>
                <ConditionData> The city name provided by the user does
                    not exist in the country.</ConditionData>
                </Condition>
                <Condition>
                    <ConditionCode>RT0004</ConditionCode>
                    <ConditionData> The search for the service area
                        information has failed.</ConditionData>
                    </Condition>
                </Status>
            </Response></res:RoutingErrorResponse>|;
    });

    my $mocked_xml_document = Test::MockModule->new('XTracker::DHL::XMLDocument');

    $mocked_xml_document->mock('parse_xml_response', sub { return {
                'error' => {
                    'RT0008' => 'The city name provided by the user does not exist in the country.',
                    'RT0004' => 'The search for the service area information has failed.',
                    'RT0006' => 'The postal code provided by the user is invalid.'
                }
            };
        });

    my $return = get_dhl_destination_code($self->dbh, $shipment->id);
    ok( ! $return, "No destination code is set");

    my $qry = "SELECT * FROM routing_request_log WHERE shipment_id = ? AND error_code = ?";
    my $sth = $self->dbh->prepare($qry);
    $sth->execute($shipment->id, 'RT0006');
    my $row;
    $row = decode_db( $sth->fetchrow_hashref() );

    ok( ( exists $row->{error_code} && $row->{error_code} eq 'RT0006' ),
        "Error code has been logged");

    ok( ( exists $row->{error_message} &&
        $row->{error_message} eq 'The postal code provided by the user is invalid.'),
        "Error code has been logged");
}}

sub z_test_non_ascii_address : Tests {
    # This test needs to run towards the end as it redefines things needed by other tests
    my $self = shift;

    my $dhl_request_xml = generate_address_validation_xml( {
            location          => 'NonASCIICharacters',
            dutiable_country  => 0,
            voucher_only      => 0,
            current_time      => $self->{current_time},
    } );

    ok( Encode::is_utf8(Encode::decode("UTF-8",$dhl_request_xml, DIE_ON_ERR | LEAVE_SRC)), "DHL XML is valid UTF8" );
}

sub z_test_county_in_division : Tests { SKIP: {
    # This test needs to run towards the end as it redefines things needed by other tests
    my $self = shift;

    my $address = Test::XTracker::Data->create_order_address_in('Ireland_Other');
    note( p($address->county) );

    my $dhl_request_xml = generate_address_validation_xml( {
            location          => 'Ireland_Other',
            dutiable_country  => 1,
            voucher_only      => 0,
            current_time      => $self->{current_time},
    } );

    my $doc = XML::LibXML->load_xml(string => $dhl_request_xml);
    my $division = $doc->findvalue('ns1:RouteRequest/Division') // '';

    ok($address->county eq $division, "Division is populated with County data");
}}

sub z_test_origin_country_code : Tests {
    my $self = shift;

    my $local_dc_country = config_var('DistributionCentre', 'alpha-2');

    my $xml_origin_country_code = 'ns1:RouteRequest/OriginCountryCode';

    my $dhl_request_xml = generate_address_validation_xml( {
            location          => 'current_dc',
            dutiable_country  => 0,
            voucher_only      => 0,
            current_time      => $self->{current_time},
    } );

    my $doc = XML::LibXML->load_xml(string => $dhl_request_xml);
    my $code = $doc->findvalue($xml_origin_country_code) // '';
    ok($code eq $local_dc_country, "Origin country code matches local DC");
}

=head2 z_test_autofill_town

Tests that the Town field will get replaced with the alternate Town from config
field if it's empty and the config allows it.

=cut

sub z_test_autofill_town : Tests { SKIP: {
    my $self    = shift;

    my $xml_to_city_name = 'ns1:RouteRequest/City';
    my $config  = \%XTracker::Config::Local::config;
    my ( $autofill_section, $autofill_city_section );
    my ( %clone_autofill_section, %clone_autofill_city_section );

    if ( exists $config->{DHL}{autofill_town_if_blank} ) {
        $autofill_section       = $config->{DHL}{autofill_town_if_blank};
        %clone_autofill_section = %{ $autofill_section };
    }
    if ( exists $config->{DHL}{autofill_address_validation_city} ) {
        $autofill_city_section   = $config->{DHL}{autofill_address_validation_city};
        %clone_autofill_city_section = %{ $autofill_city_section };
    }
    my $shipment    = $self->{shipment};
    my $address     = $shipment->shipment_address;

    # get the Country Code for the Shipping Address
    my $country_code = $address->country_ignore_case->code;

    my %tests   = (
        "Empty Town, should populate with New Town" => {
            address => {
                towncity => '',
            },
            config  => {
                $country_code => 1,
            },
            alternate  => {
                $country_code => 'New Town',
            },
            expect_town => 'New Town',
        },
        "Non-Empty Town, should populate with New Town" => {
            address => {
                towncity=> 'Town',
                county  => 'County',
            },
            config  => {
                $country_code => 1,
            },
            alternate  => {
                $country_code => 'New Town',
            },
            expect_town => 'New Town',
        },
        "Non-Empty Town but Country isn't in config" => {
            address => {
                towncity=> 'Town',
            },
            config  => { },
            expect_town => 'Town',
        },
        "Empty Town but Country isn't in Config" => {
            address => {
                towncity=> '',
            },
            config  => { },
            expect_town => '',
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        $address->update( { %{ $test->{address} } } );
        $address->discard_changes;

        $config->{DHL}{autofill_town_if_blank} = $test->{config};
        $config->{DHL}{autofill_address_validation_city} = $test->{alternate};

        my $dhl_request_xml = generate_address_validation_xml( {
            address           => $address,
            dutiable_country  => 0,
            voucher_only      => 0,
            current_time      => $self->{current_time},
        } );

        # parse the XML that was going to be sent to the API
        my $doc = XML::LibXML->load_xml( string => $dhl_request_xml );

        # check town name obtained from XML response
        my $got_town    = $doc->findvalue($xml_to_city_name) // '';
        is( $got_town, $test->{expect_town},
                        "Town in XML Request is as Expected: '" . $test->{expect_town} . "'" );
    }
}}

sub get_order_shipment_id {
    my $args = shift;

    my $order_data = create_an_order( { %{$args} } );

    my $shipment = $order_data->shipments->first;

    return $shipment->id;
}

# Checks if special characters in XML for DHL are removed/transformed into ASCII
#
sub check_special_characters_in_dhl_request_xml :Tests {
    my $self = shift;

     my $address = Test::XTracker::Data->create_order_address_in('current_dc');
     my @channels = Test::XTracker::Data->get_enabled_channels->all;

    my $order_data = create_an_order( {
        channel_id       => $channels[0]->id,
        address          => $address,
        dutiable_country => 1,
        voucher_only     => 0,
    } );

    my $shipment = Test::MockObject::Extends->new(
        $order_data->shipments->first
    );
    my $declaration_info = $shipment->export_declaration_information;
    $_->{description} = "TEST_FOR_DCOP-1121: '\N{TRADE MARK SIGN}'" for values %$declaration_info;

    # extend shipment to always return declaration information as string with special character
    $shipment->mock(export_declaration_information => sub{ $declaration_info });
    $shipment->mock(is_between_eu_member_states => sub{ !!undef });

    my $xml_for_dhl = XTracker::DHL::XMLDocument::build_label_request_xml({shipment => $shipment});

    like($xml_for_dhl, qr/TEST_FOR_DCOP\-1121: 'tm'/, 'Special characters are removed from DHL XML');
}

# Check if shipment requests archive label

sub check_archive_label_flag :Tests {
    my $self = shift;

    my $address = Test::XTracker::Data->create_order_address_in('IntlWorld');
    my @channels = Test::XTracker::Data->get_enabled_channels->all;

    my $parser = XML::LibXML->new;

    my %tests =  (
        "Dutiable shipment should request archive label" => {
            order_args => {
                channel_id       => $channels[0]->id,
                address          => $address,
                dutiable_country => 1,
                voucher_only     => 0,
            },
            expected_flag => 'Y',
        },
        "Voucher shipment should not request archive label" => {
            order_args => {
                channel_id       => $channels[0]->id,
                address          => $address,
                dutiable_country => 1,
                voucher_only     => 1,
            },
            expected_flag => 'N',
        },
    );

    foreach my $shipment_type ( keys %tests ) {
        note "Testing: ${shipment_type}";

        my $test = $tests{$shipment_type};

        my $order_data = create_an_order($test->{order_args});

        my $shipment = Test::MockObject::Extends->new(
            $order_data->shipments->first
        );

        my $xml_for_dhl = XTracker::DHL::XMLDocument::build_label_request_xml({shipment => $shipment});

        my $doc = $parser->parse_string($xml_for_dhl);
        my $root = $doc->getDocumentElement;
        my $archive_flag = $root->findvalue('RequestArchiveDoc');

        is( $archive_flag, $test->{expected_flag}, 'Archive flag as expected');
    }
}


sub generate_address_validation_xml {
    my $args = shift;

    my $address = $args->{address} // Test::XTracker::Data->create_order_address_in($args->{location});

    my @channels = Test::XTracker::Data->get_enabled_channels->all;

    # create order to a dutiable country
    my $order_data = create_an_order( {
        channel_id       => $channels[0]->id,
        address          => $address,
        dutiable_country => $args->{dutiable_country},
        voucher_only     => $args->{voucher_only},
    } );

    my $shipment = $order_data->shipments->first;

    # need to pass date and country_code too
    my $test_address = {
        country_code => $shipment->get_shippable_country_code,
        date         => '2013-02-18T15:39:31+00:00',
        map { $_ => $address->$_ }
                qw/ address_line_1 address_line_2 towncity county postcode country /,
    };

    my $xml = XTracker::DHL::XMLDocument::build_request_xml( {
            shipment_address => $test_address,
            is_dutiable      => $shipment->is_dhl_dutiable,
            shipment_value   => $shipment->total_price,
            current_time     => $args->{current_time},
    } );

    return $xml;
}

=head2 create_an_order

Create an order using various arguments passed in from each test.

Call like:
    my $order_data = create_an_order( {
        channel_id => $channels[0]->id,
        address => $address,
    } );

Parameters required:
channel_id - id of enabled channel
address    - ref of hash that contains the order address

Optional parameters:
voucher_only     - boolean value to create voucher only order
dutiable_country - boolean value to create international order (dutiable in DHL terms)

Returns L<XTracker::Schema::Result::Public::Orders> object.
=cut
sub create_an_order {
    my $args    = shift;

    my $item_channel_id  = $args->{channel_id};

    note "Creating Order";

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        channel_id => $item_channel_id,
        phys_vouchers   => {
            how_many                 => 1,
            want_stock               => 1,
            value                    => '150.00',
            assign_code_to_ship_item => 1,
        },
        virt_vouchers   => {
            how_many                 => 1,
            value                    => '250.00',
            assign_code_to_ship_item => 1,
        },
    });
    my @pids_to_use;
    push @pids_to_use, $pids->[0] if ( !$args->{voucher_only} );
    push @pids_to_use, $pids->[1];

    my $address = $args->{address};

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $base = {
        channel_id           => $channel->id,
        invoice_address_id   => $address->id,
    };
    $base->{shipment_type} = $SHIPMENT_TYPE__INTERNATIONAL if $args->{dutiable_country};

    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => \@pids_to_use,
        base => $base,
        attrs => [
            { price => 100.00 },
        ],
    });

    # update some dates so they are not 'today' for future tests
    $order->update( { date => $order->date->subtract( days => 1 ) } );
    $order->get_standard_class_shipment->update( { date => $order->date } );

    return $order;
}

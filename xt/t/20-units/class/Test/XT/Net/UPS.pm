package Test::XT::Net::UPS;
use NAP::policy "tt", 'test', 'class';
use Test::XTracker::LoadTestConfig;

BEGIN {

    extends "NAP::Test::Class";

    use Test::XTracker::Data::Carrier::UPS;
    has 'ups_test_data' => (
        is      => 'ro',
        isa     => 'Test::XTracker::Data::Carrier::UPS',
        lazy    => 1,
        default => sub { Test::XTracker::Data::Carrier::UPS->new() },
    );

    use Test::XTracker::Carrier;
    has 'carrier_test_helper' => (
        is       => 'ro',
        isa      => 'Test::XTracker::Carrier',
        lazy     => 1,
        default  => sub { Test::XTracker::Carrier->new() },
        handles  => {
            create_ups_shipment => 'ups_shipment',
        }
    );

};

use Test::XTracker::LoadTestConfig;
use Test::MockObject;
use Test::MockModule;
use XT::Net::UPS;

sub test__basic {
    my ($self) = @_;

    use_ok('XT::Net::UPS');

    my $net_ups_obj = $self->_create_net_ups();
    isa_ok($net_ups_obj, 'XT::Net::UPS');

    can_ok($net_ups_obj,
        # Methods inherited from Net::UPS
        # (followed by)
        # Methods defined in XT::Net::UPS
        qw/
            access_as_xml
            access_key
            instance
            password
            rate
            service
            shop_for_rates
            userid
            validate_address

            error
            set_error
            proxy
            set_proxy
            config
            process_xml_request
            xml_request
            prepare_shipping_accept_xml
            _prepare_shipping_confirm_xml
            shipping_accept_proxy
            shipping_confirm_proxy
        /
    );
}

sub test__prepare_shipping_confirm_xml :Tests {
    my ($self) = @_;

    my $net_ups_obj = $self->_create_net_ups();
    my $shipment_obj = $self->create_ups_shipment();
    # update the Shipment to make sure Delivery Signature is Required
    $shipment_obj->update({ signature_required => 1 });

    # Test for an outgoing shipment
    my $outgoing_confirm_xml = $net_ups_obj->_prepare_shipping_confirm_xml($shipment_obj, 0);
    isa_ok($outgoing_confirm_xml, 'HASH', 'what prepare_shipping_confirm_xml returned' );
    is($outgoing_confirm_xml->{ShipmentConfirmRequest}{Request}{TransactionReference}{CustomerContext},
        'OUTBOUND-'.$shipment_obj->id, 'Outbound Trans Ref found' );
    is($outgoing_confirm_xml->{ShipmentConfirmRequest}{Shipment}{Shipper}{Address}{City},
        'Mahwah', "Shipper's City (IE. NaP) is 'Mahwah'" );
    is($outgoing_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ShipFrom}{Address}{City},
        'Mahwah', "ShipFrom City (IE. NaP) is 'Mahwah'" );
    isa_ok($outgoing_confirm_xml->{ShipmentConfirmRequest}{Shipment}{Package},
        'ARRAY','Package part of data' );

    # Now test for a return
    my $return_confirm_xml = $net_ups_obj->_prepare_shipping_confirm_xml($shipment_obj, 1);
    isa_ok( $return_confirm_xml, 'HASH', 'what prepare_shipping_confirm_xml returned for a return' );
    is( $return_confirm_xml->{ShipmentConfirmRequest}{Request}{TransactionReference}{CustomerContext},
        'RETURN-'.$shipment_obj->id, 'Return Trans Ref found' );
    is( $return_confirm_xml->{ShipmentConfirmRequest}{Shipment}{Shipper}{Address}{City},
        'Mahwah', "RETURN Shipper's City (IE. NaP) is 'Mahwah'" );
    is( $return_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ShipTo}{Address}{City},
        'Mahwah', "RETURN ShipTo City (IE. NaP) is 'Mahwah'" );
    ok(exists($return_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ReturnService} ),
        'Found ReturnService Key for Returns' );
    isa_ok($return_confirm_xml->{ShipmentConfirmRequest}{Shipment}{Package},
        'ARRAY','Package part of Return data' );

    # first check the email addresses exist then delete them as apart from this field ShipTo and ShipFrom should be the same
    # so we can then test that those 2 have swapped over for the return call compare with the oubound call
    ok( exists( $outgoing_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ShipTo}{EMailAddress} ),
        'Email Address exists in Outbound ShipTo details' );
    ok( exists( $return_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ShipTo}{EMailAddress} ),
        'Email Address exists in Return ShipTo details' );
    delete $return_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ShipTo}{EMailAddress};
    delete $outgoing_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ShipTo}{EMailAddress};

    # ShipTo and ShipFrom addresses should have swapped round
    is_deeply($return_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ShipFrom},
        $outgoing_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ShipTo},
        "Return ShipFrom = Outbound ShipTo - They've been Switched" );
    is_deeply($return_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ShipTo},
        $outgoing_confirm_xml->{ShipmentConfirmRequest}{Shipment}{ShipFrom},
        "Return ShipTo = Outbound ShipFrom - They've been Switched" );

    # Delivery Confirmation only available for OUTBOUND not RETURN
    # in PackageSerivceOptions for packages
    my $out_pckg = $outgoing_confirm_xml->{ShipmentConfirmRequest}{Shipment}{Package}->[0];
    my $ret_pckg = $return_confirm_xml->{ShipmentConfirmRequest}{Shipment}{Package}->[0];
    ok( defined $out_pckg->{PackageServiceOptions}
        && exists( $out_pckg->{PackageServiceOptions}{DeliveryConfirmation}{DCISType} ),
        'Delivery Confirmation found in OUTBOUND Call' );
    cmp_ok( $out_pckg->{PackageServiceOptions}{DeliveryConfirmation}{DCISType}, '==', 2,
        "'DCISType' value is '2'" );
    ok( !defined $ret_pckg->{PackageServiceOptions},
        'Delivery Confirmation NOT found in RETURN Call' );

    # Try again with signature required set to NULL
    $shipment_obj->update({ signature_required => undef });
    $out_pckg = $net_ups_obj->_prepare_shipping_confirm_xml($shipment_obj, 0)
        ->{ShipmentConfirmRequest}{Shipment}{Package}[0];
    ok( exists( $out_pckg->{PackageServiceOptions}{DeliveryConfirmation}{DCISType} ),
        "for 'NULL' value in 'signature_required' field, got 'PackageServiceOptions/DeliveryConfirmation/DCISType' tag in XML" );
    cmp_ok($out_pckg->{PackageServiceOptions}{DeliveryConfirmation}{DCISType}, '==', 2,
        "'DCISType' value is '2'" );

    # Try with signature required set to false
    $shipment_obj->update( { signature_required => 0 } );
    $out_pckg = $net_ups_obj->_prepare_shipping_confirm_xml($shipment_obj)->{ShipmentConfirmRequest}{Shipment}{Package}[0];
    ok(!exists($out_pckg->{PackageServiceOptions} ),
        "for 'FALSE' value in 'signature_required' field, did NOT get 'PackageServiceOptions' tag in XML" );
}

sub test__request_shipping_confirm :Tests {
    my ($self) = @_;

    my $mocked_net_ups = Test::MockModule->new('XT::Net::UPS');
    $mocked_net_ups->mock('_prepare_shipping_confirm_xml', sub {
        # Just the barebones will do for this test
        return {
            ShipmentConfirmRequest => { Shipment => { Service => {} }, },
        };
    });
    $mocked_net_ups->mock('process_xml_request', sub {
        my ($self, $args) = @_;
        my $code = $args->{xml_data}->{ShipmentConfirmRequest}->{Shipment}->{Service}->{Code};

        # Add some hard-coded responses
        if ( grep { $_ eq $code } ('Terror1', 'Terror2') ) {
            # Simulate an error
            $self->set_error('Nasty old error');
            $self->set_xml_response({
                Response => { Error => { ErrorCode => '42' }},
            });
            $self->_set_raw_xml('<XML>XML smells</XML>');
            return 0;
        } elsif( grep { $_ eq $code } ('Tsuccess1') ) {
            # Simulate a success
            $self->set_error(undef);
            $self->set_xml_response({
                Response => { Status => 'All good' },
            });
            $self->_set_raw_xml('<XML>XML really does smell</XML>');
            return 1;
        }
    });

    my $net_ups_obj = $self->_create_net_ups();

    my @available_services = $self->ups_test_data->create_ups_services([{
            code                        => 'error1',
            description                 => 'error number 1',
        }, {
            code                        => 'error2',
            description                 => 'error number 2',
        }
    ]);

    # Need a mock shipment, though it isn't actually used for anything now that we've
    # mocked the 'prepare'
    my $mock_shipment = Test::MockObject->new();
    $mock_shipment->set_isa('XTracker::Schema::Result::Public::Shipment');

    my ($success, $error_data) = $net_ups_obj->request_shipping_confirm(
        shipment            => $mock_shipment,
        available_services  => \@available_services,
    );
    is($success, 0, 'request_shipping_confirm() with two failed services returns failed');
    is($net_ups_obj->proxy(), 'http://baseurl.com/xml/shipconfirm', 'proxy set correctly');

    is_deeply($error_data, [
        {
            error       => 'Nasty old error',
            errcode     => '42',
            proxy       => 'http://baseurl.com/xml/shipconfirm',
            request     => {
                ShipmentConfirmRequest => {
                    Shipment => {
                        Service => {
                            Code        => 'Terror1',
                            Description => 'error number 1',
                        }
                    },
                },
            },
            response    => { Response => { Error => { ErrorCode => '42' }}},
            service     => { code => 'Terror1', description => 'error number 1' },
            xml         => '<XML>XML smells</XML>',
        },
        {
            error       => 'Nasty old error',
            errcode     => '42',
            proxy       => 'http://baseurl.com/xml/shipconfirm',
            request     => {
                ShipmentConfirmRequest => {
                    Shipment => {
                        Service => {
                            Code        => 'Terror2',
                            Description => 'error number 2',
                        }
                    },
                },
            },
            response    => { Response => { Error => { ErrorCode => '42' }}},
            service     => { code => 'Terror2', description => 'error number 2' },
            xml         => '<XML>XML smells</XML>',
        }
    ], 'Error data as expected');

    @available_services = $self->ups_test_data->create_ups_services([{
            code                        => 'error1',
            description                 => 'error number 1',
        }, {
            code                        => 'success1',
            description                 => 'success!',
        }
    ]);

    ($success, $error_data) = $net_ups_obj->request_shipping_confirm(
        shipment            => $mock_shipment,
        available_services  => \@available_services
    );
    is($success, 1,
        'request_shipping_confirm() with one failed services and a success returns ok');

    is_deeply($error_data, [
        {
            error       => 'Nasty old error',
            errcode     => '42',
            proxy       => 'http://baseurl.com/xml/shipconfirm',
            request     => {
                ShipmentConfirmRequest => {
                    Shipment => {
                        Service => {
                            Code        => 'Terror1',
                            Description => 'error number 1',
                        }
                    },
                },
            },
            response    => { Response => { Error => { ErrorCode => '42' }}},
            service     => { code => 'Terror1', description => 'error number 1' },
            xml         => '<XML>XML smells</XML>',
        },
    ], 'Error data as expected');
}


sub _create_net_ups {
    my ($self) = @_;

    return XT::Net::UPS->new({
        config => $self->_create_mock_config(),
    });
}

sub _create_mock_config {
    my ($self) = @_;

    my $mock_config = Test::MockObject->new();
    $mock_config->set_isa('NAP::Carrier::UPS::Config');
    $mock_config->mock('base_url', sub { 'http://baseurl.com/xml' });
    $mock_config->mock('shipconfirm_service', sub { '/shipconfirm' });
    $mock_config->mock('shipaccept_service', sub { '/shipaccept' });
    $mock_config->mock('shipaccept_service', sub { '/shipaccept' });
    $mock_config->mock('username', sub { 'bob' });
    $mock_config->mock('password', sub { 'pass' });
    $mock_config->mock('xml_access_key', sub { 'akey' });

    return $mock_config;
}

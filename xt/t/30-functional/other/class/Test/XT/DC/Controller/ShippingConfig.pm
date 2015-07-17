package Test::XT::DC::Controller::ShippingConfig;
use NAP::policy qw/test/;
use parent 'NAP::Test::Class';
use Test::XTracker::Mechanize;
use Test::XTracker::Data;
use Data::Dumper;
use JSON;

=head2 startup__create_test_data

Startup method; creates a feature-exhaustive dataset

=cut

sub startup__create_test_data :Test(startup) {
    my ($self) = @_;

    my $schema = $self->schema();

    # We have to do this because channels have been added without using the sequence, but
    # the test setup relies on the sequence being in sync with the data.
    $schema->storage->dbh->do("SELECT SETVAL('sos.channel_id_seq', (SELECT max(id) FROM sos.channel))");

    # Processing Times
    my $processing_time_rs = $schema->resultset('SOS::ProcessingTime');
    # Remove existing processing times
    $processing_time_rs->delete();

    for my $processing_time (
        {
        # Shipment class with "classic" override
            class => {
                name        => 'Bog Standard',
                api_code    => 'BOGSTANDARD',
                does_ignore_other_processing_times => 'f',
            },
            processing_time => '02:00:00',
            processing_time_override_major_ids => [
                {
                    minor => {
                        class => {
                            name        => 'Dog Standard',
                            api_code    => 'DOGSTANDARD',
                        },
                        processing_time => '02:00:00',
                    },
                },
            ],
        },
        {
        # Shipment class with "all" override
            class => {
                name        => 'Bog Deluxe',
                api_code    => 'BOGDELUXE',
                does_ignore_other_processing_times => 't',
            },
            processing_time => '02:00:00',
        },
        {
        # Country
            country => {
                name        => 'Bizarroland',
                api_code    => 'BL',
            },
            processing_time => '02:00:00',
        },
        {
        # Region
            region => {
                name        => 'Demilitarised Zone',
                api_code    => 'DZ',
                country => {
                    name        => 'Latveria',
                    api_code    => 'XX',
                },
            },
            processing_time => '02:00:00',
        },
        # Class attribute
        {
            class_attribute =>  {
                name => 'Classy',
            },
            processing_time => '02:00:00',
        },
        # Channel
        {
            channel => {
                name        => 'Bertie\'s Brilliant Boots',
                api_code    => 'BBB',
            },
            processing_time => '02:00:00',
        }
    ) {
        $processing_time_rs->create($processing_time);
    }

    # WMS priorities
    my $wms_rs = $schema->resultset('SOS::WmsPriority');
    $wms_rs->delete();

    for my $wms_priority (
        {
        # Shipment class with no "all" override
            shipment_class => {
                name        => 'Fog Standard',
                api_code    => 'FOGSTANDARD',
            },
            wms_priority    => 20,
            wms_bumped_priority => 15,
            bumped_interval => '02:00:00',
        },
        {
        # Shipment class with "all" override
            shipment_class => {
                name        => 'Fog Deluxe',
                api_code    => 'FOGDELUXE',
            },
            wms_priority    => 20,
            wms_bumped_priority => 15,
            bumped_interval => '02:00:00',
        },
        {
        # Country
            country => {
                name        => 'Atlantis',
                api_code    => 'AT',
            },
            wms_priority    => 20,
            wms_bumped_priority => 15,
            bumped_interval => '02:00:00',
        },
        {
        # Region
            region => {
                name        => 'Haunted House',
                api_code    => 'HH',
                country => {
                    name        => 'Transylvania',
                    api_code    => 'TV',
                },
            },
            wms_priority    => 20,
            wms_bumped_priority => 15,
            bumped_interval => '02:00:00',
        },
        # Class attribute
        {
            shipment_class_attribute =>  {
                name => 'UnClassy',
            },
            wms_priority    => 20,
            wms_bumped_priority => 15,
            bumped_interval => '02:00:00',
        },
    ) {
        $wms_rs->create($wms_priority);
    }
}

=head2 test__get_methods

Tests GET for API methods

=cut

sub test__get_methods :Tests {
    my ($self) = @_;
    # Get the expected lengths of each method call
    my $schema = $self->schema;
    my $processing_time_length = $schema->resultset('SOS::ProcessingTime')->count;
    my $wms_priority_length = $schema->resultset('SOS::WmsPriority')->count;
    my $mech = Test::XTracker::Mechanize->new;

    # grant permissions
    Test::XTracker::Data->grant_permissions(
        'it.god',
        'Admin',
        'Shipping Config',
         1
    );

    for my $test (
        {
            name    =>  'Get processing times configuration',
            service =>  '/shippingconfig/',
            method  =>  'processing_times',
            result  =>  {
                expected_length => $processing_time_length,
            }
        },
        {
            name    =>  'Get WMS priorities configuration',
            service =>  '/shippingconfig/',
            method  =>  'wms_priorities',
            result  =>  {
                expected_length => $wms_priority_length,
            }
        }
    ) {
        subtest $test->{name} => sub {

            $mech->do_login;
            $mech->get_ok($test->{service} . $test->{method});

            my $response = $mech->content;

            # Check response is well-formed JSON
            my $response_content = undef;
            try {
                $response_content = decode_json($response);
            }
            catch {
                diag("Badly-formed JSON response from\
                         shippingconfig/processing_times");
            };

            ok($response_content, "Response is well-formed JSON")
                or diag($response);

            # check response has expected payload data length
            is(scalar keys %{$response_content->{payload}},
                $test->{result}->{expected_length},
                "Payload has expected length");
        }
    }
}

=head2 test__post_method_responses

Tests POST for API methods

=cut

sub test__post_method_responses :Tests {
    my ($self) = @_;
    # Get the expected lengths of each method call
    my $schema = $self->schema;
    my $mech = Test::XTracker::Mechanize->new;

    # Get a valid record ID for each method
    my $processing_time_id = $schema->resultset('SOS::ProcessingTime')->first->id;
    my $wms_priority_id = $schema->resultset('SOS::WmsPriority')->first->id;

    # grant permissions, login and get response
    Test::XTracker::Data->grant_permissions(
        'it.god',
        'Admin',
        'Shipping Config',
         1
    );

    for my $test (
        # processing_times
        {
            name    =>  'Processing Time - No errors',
            service =>  '/shippingconfig/',
            method  =>  'processing_times',
            parameters  => {
                id  => $processing_time_id,
                processing_time => '200',
            },
            result  => {
                success => 1,
                expected_error  => 'This should not error',
            }
        },
        {
            name    =>  'Processing Time - invalid id',
            service =>  '/shippingconfig/',
            method  =>  'processing_times',
            parameters  => {
                id   => undef,
                processing_time => '200',
            },
            result  => {
                success => 0,
                expected_error => 'Invalid parameter: id',
            }
        },
        {
            name    =>  'Processing Time - nonexistent id',
            service =>  '/shippingconfig/',
            method  =>  'processing_times',
            parameters  => {
                id   => '999999999',
                processing_time => '200',
            },
            result  => {
                success => 0,
                expected_error => 'Nonexistent row-id: 999999999',
            }
       },
       {
            name    =>  'Processing time - undefined time',
            service =>  '/shippingconfig/',
            method  =>  'processing_times',
            parameters  => {
                id   => "$processing_time_id",
                processing_time => undef,
            },
            result  => {
                success => 0,
                expected_error => 'Undefined parameter: time',
            }
        },
        {
            name    =>  'Processing time - non-integer time',
            service =>  '/shippingconfig/',
            method  =>  'processing_times',
            parameters  => {
                id   => "$processing_time_id",
                processing_time => 'Text!',
            },
            result  => {
                success => 0,
                expected_error => 'Non-integer parameter: time',
            }
        },
        # wms_priorities
        {
            name    =>  'WMS Priorities - no errors',
            service =>  '/shippingconfig/',
            method  =>  'wms_priorities',
            parameters  => {
                id   => "$wms_priority_id",
                processing_time => '200',
                initial_priority => '20',
                bumped_priority => '15',
                bumped_interval => '200',
            },
            result  => {
                success => 1,
                expected_error => 'Should not error',
            }
        },
        {
            name    =>  'WMS Priorities - invalid id',
            service =>  '/shippingconfig/',
            method  =>  'wms_priorities',
            parameters  => {
                id   => undef,
                processing_time => '200',
                initial_priority => '20',
            },
            result  => {
                success => 0,
                expected_error => 'Undefined parameter: id',
            }
        },
        {
            name    =>  'WMS Priorities - undefined initial priority',
            service =>  '/shippingconfig/',
            method  =>  'wms_priorities',
            parameters  => {
                id   => "$wms_priority_id",
                processing_time => '200',
                initial_priority => undef,
            },
            result  => {
                success => 0,
                expected_error => 'Undefined parameter: initial_priority',
            }
        },
        {
            name    =>  'WMS Priorities - nonexistent row_id',
            service =>  '/shippingconfig/',
            method  =>  'wms_priorities',
            parameters  => {
                id   => "999999999",
                processing_time => '200',
                initial_priority => '20',
            },
            result  => {
                success => 0,
                expected_error => 'Nonexistent row-id: 999999999',
            }
        },
        {
            name    =>  'WMS Priorities - non-integer initial_priority',
            service =>  '/shippingconfig/',
            method  =>  'wms_priorities',
            parameters  => {
                id   => "999999999",
                processing_time => '200',
                initial_priority => 'TEXT!',
            },
            result  => {
                success => 0,
                expected_error => 'Non-integer parameter initial_priority',
            }
        },
        {
            name    =>  'WMS Priorities - non-integer bumped_priority',
            service =>  '/shippingconfig/',
            method  =>  'wms_priorities',
            parameters  => {
                id   => "999999999",
                processing_time => '200',
                initial_priority => '20',
                bumped_priority => 'TEXT!',
            },
            result  => {
                success => 0,
                expected_error => 'Non-integer parameter bumped_priority',
            }
        },
        {
            name    =>  'WMS Priorities - non-integer bumped_priority',
            service =>  '/shippingconfig/',
            method  =>  'wms_priorities',
            parameters  => {
                id   => "999999999",
                processing_time => '200',
                initial_priority => '20',
                bumped_priority => '15',
                bumped_interval => 'TEXT!',
            },
            result  => {
                success => 0,
                expected_error => 'Non-integer parameter bumped_interval',
            }
        },
    ) {
        subtest $test->{name} => sub {
            my $base = $mech->base;
            $base =~ s#^(.*?//.*?/).*#$1#; # because $mech->base gives us e.g. http://localhost.localdomain:8529/Home
            my $url = $base . $test->{service} . $test->{method};
            $mech->do_login;
            $mech->add_header( Accept => 'application/json');
            note("Test: $test->{name}");
            my $response = $mech->post(
                $url,
                $test->{parameters},
            );

            # Check the response is valid JSON
            my $response_json = undef;
            try {
                $response_json = decode_json($response->decoded_content);
            } catch {
                diag($response->decoded_content);
            };

            ok($response_json, "Response is valid JSON");

            if($test->{result}->{success} == 0) {
                # If the test is supposed to fail,
                # check it fails for the right reasons
                is(
                    $response_json->{error},
                    $test->{result}->{expected_error},
                    "Correct error response received",
                );
            } else {
                # Check we get a happy response
                is ($response->code, 200, "Returned successful")
                    or diag(Dumper($response_json));
            }
        }
    }
}

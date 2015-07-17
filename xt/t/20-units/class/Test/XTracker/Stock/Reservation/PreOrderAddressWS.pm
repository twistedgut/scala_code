package Test::XTracker::Stock::Reservation::PreOrderAddressWS;

use NAP::policy "tt", qw( test );

use parent 'NAP::Test::Class';

=head1 NAME

Test::XTracker::Stock::Reservation::PreOrderAddressWS

=head1 DESCRIPTION

Tests Creating/Updating a Pre-Order's Shipping & Invoice Address.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Mock::Handler;

use XTracker::Config::Local             qw( config_var );
use XTracker::Stock::Reservation::PreOrderAddressWS;
use XTracker::Constants::Address        qw( :address_ajax_messages
                                            :address_types );

use XTracker::Error     qw();


=head1 TESTS

=cut

sub startup : Test(startup) {
    my ($self) = @_;

    $self->SUPER::startup;

    $self->{schema}       = Test::XTracker::Data->get_schema();
    $self->{pre_order}    = Test::XTracker::Data::PreOrder->create_complete_pre_order();
}

sub setup : Test(setup) {
    my ($self) = @_;

    $self->SUPER::setup;

    $self->{schema}->txn_begin;

    $self->{test_address} = {
        first_name     => 'John',
        last_name      => 'Smith',
        address_line_1 => '1 Road',
        address_line_2 => 'line2',
        address_line_3 => 'line3',
        towncity       => 'Atown',
        postcode       => 'ABC123',
        county         => 'Somewhere',
        country        => 'Albania',
    }
}

sub test_create_address_with_missing_data : Tests() {
    my ($self) = @_;

    my $field_to_delete = 'first_name';

    $self->{test_address}{$field_to_delete} = '';

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            %{$self->{test_address}},
        }
    });

    my $ajax = new_ok('XTracker::Stock::Reservation::PreOrderAddressWS' => [$mock_handler]);
    my $output = $ajax->order_address_POST();

    $self->test_for_error_message($output, qr/\AThe following are required:\s+First Name\Z/s );
}

sub test_get_address : Tests() {
    my ($self) = @_;

    $self->{test_address}{postcode} = '';

    my $address = $self->{schema}->resultset('Public::OrderAddress')->create({%{$self->{test_address}}, address_hash=>'abc'});

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            address_id => $address->id
        }
    });

    my $ajax = new_ok('XTracker::Stock::Reservation::PreOrderAddressWS' => [$mock_handler]);
    my $output = $ajax->order_address_GET();

    if ($self->test_for_no_error_message($output)) {
        foreach my $field (keys %{$self->{test_address}}) {
            is($output->{$field}, $self->{test_address}{$field}, "Correct data retured for $field");
        }
    }
}

sub test_create_orphan_address : Tests() {
    my ($self) = @_;

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            %{$self->{test_address}}
        }
    });

    my $ajax = new_ok('XTracker::Stock::Reservation::PreOrderAddressWS' => [$mock_handler]);
    my $output = $ajax->order_address_POST();

    if ($self->test_for_no_error_message($output)) {
        ok(!exists($output->{errmsg}), 'No error message returned');
        cmp_ok($output->{ok}, '==', 1, 'Got OK from ajax');
    }
}

sub test_create_pre_order_address_with_no_type : Tests() {
    my ($self) = @_;

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id   => $self->{pre_order}->id,
            %{$self->{test_address}}
        }
    });

    my $ajax = new_ok('XTracker::Stock::Reservation::PreOrderAddressWS' => [$mock_handler]);
    my $output = $ajax->order_address_POST();

    $self->test_for_error_message($output, $ADDRESS_AJAX_MESSAGE__NO_ADDRESS_TYPE_PROVIDED);
}

sub test_create_pre_order_address_with_unknown_type : Tests() {
    my ($self) = @_;

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id   => $self->{pre_order}->id,
            %{$self->{test_address}}
        }
    });

    my $ajax = new_ok('XTracker::Stock::Reservation::PreOrderAddressWS' => [$mock_handler]);
    my $output = $ajax->order_address_POST();

    $self->test_for_error_message($output, $ADDRESS_AJAX_MESSAGE__NO_ADDRESS_TYPE_PROVIDED);
}

sub test_create_pre_order_unknown_address_type : Tests() {
    my ($self) = @_;

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id   => $self->{pre_order}->id,
            address_type   => 'WHAT AM I?',
            %{$self->{test_address}}
        }
    });

    my $ajax = new_ok('XTracker::Stock::Reservation::PreOrderAddressWS' => [$mock_handler]);
    my $output = $ajax->order_address_POST();

    $self->test_for_error_message($output, $ADDRESS_AJAX_MESSAGE__UNKNOWN_ADDRESS_TYPE_PROVIDED);
}

=head2 test_create_address_with_missing_county

This checks that for Countries with Sub-Divisions (and that have been configured to check as well) will
throw a Warning if the 'county/state' of the Address is not one of them.

=cut

sub test_create_address_with_missing_county : Tests() {
    my $self    = shift;

    # store the config's original setting
    my $config = \%XTracker::Config::Local::config;
    my $orig_config_setting = $config->{countries_with_districts_for_ui}{country};

    my $dc_country  = config_var('DistributionCentre', 'country');
    my $country     = $self->rs('Public::Country')->search( {
        country => {
            'NOT IN' => [ 'Unknown', $dc_country ],
        },
    } )->first;
    my $sub_division_rs = $self->rs('Public::CountrySubdivision')->search( { country_id => $country->id } );

    # create a couple of Sub-Divisions for the Country
    $sub_division_rs->create( { name => 'Test Sub-Div' } );
    $sub_division_rs->create( { iso  => 'ZZ', name => 'Another Sub-Div' } );

    my %tests = (
        "County doesn't match one of the Country's Sub-Divisions" => {
            setup => {
                county  => 'Not a Valid County',
            },
            expect_warning => 1,
        },
        "Empty County doesn't match one of the Country's Sub-Divisions" => {
            setup => {
                county  => '',
            },
            expect_warning => 1,
        },
        "County doesn't match Country's Sub-Divisions, but Country NOT in Config" => {
            setup => {
                config  => $dc_country,
                county  => 'Not a Valid County',
            },
            expect_warning => 0,
        },
        "County doesn't match Country's Sub-Divisions, but NO Countries are in Config" => {
            setup => {
                config  => undef,
                county  => 'Not a Valid County',
            },
            expect_warning => 0,
        },
        "County doesn't match Country's Sub-Divisions and Multiple Countries in Config" => {
            setup => {
                config  => [ $country->country, $dc_country ],
                county  => 'Not a Valid County',
            },
            expect_warning => 1,
        },
        "Invoice Address: County doesn't match one of the Country's Sub-Divisions - No Warning" => {
            setup => {
                county   => 'Not a Valid County',
                param_of => {
                    address_type => $ADDRESS_TYPE__INVOICE,
                },
            },
            expect_warning => 0,
        },
        "Address for Both: County doesn't match one of the Country's Sub-Divisions - Expect Warning" => {
            setup => {
                county   => 'Not a Valid County',
                param_of => {
                    address_type => $ADDRESS_TYPE__INVOICE,
                    use_for_both => 1,
                },
            },
            expect_warning => 1,
        },
        "County matches one of the Country's Sub-Division's 'name'" => {
            setup => {
                config  => [ $country->country, $dc_country ],
                county  => 'Test Sub-Div',
            },
            expect_warning => 0,
        },
        "County matches one of the Country's Sub-Division's 'iso'" => {
            setup => {
                county  => 'ZZ',
            },
            expect_warning => 0,
        },
        "County matches another one of the Country's Sub-Division's 'name'" => {
            setup => {
                county  => 'Another Sub-Div',
            },
            expect_warning => 0,
        },
    );

    my $address = $self->{test_address};
    $address->{country} = $country->country;

    my $config_section = $config->{countries_with_districts_for_ui};

    my $got_error_type;
    my $got_error_message;

    # redefine 'xt_feeback' so as to test for warnings
    no warnings 'redefine';
    my $orig_xt_feedback = \&XTracker::Error::xt_feedback;
    *XTracker::Error::xt_feedback = sub {
        ( $got_error_type, $got_error_message ) = @_;
        note "=================================== IN REDEFINED 'xt_feedback' function ===================================";
        return;
    };
    use warnings 'redefine';

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        # set-up the Config
        if ( exists( $test->{setup}{config} ) ) {
            if ( defined $test->{setup}{config} ) {
                $config_section->{country} = $test->{setup}{config};
            }
            else {
                delete $config_section->{country};
            }
        }
        else {
            $config_section->{country} = $country->country;
        }

        # set-up the params passed to the Handler
        my $param_of = $test->{setup}{param_of} // {
            address_type => $ADDRESS_TYPE__SHIPMENT,
        };

        # set the Address' County
        $address->{county} = $test->{setup}{county};

        $got_error_type     = undef;
        $got_error_message  = undef;

        my $mock_handler = Test::XTracker::Mock::Handler->new( {
            param_of => {
                %{ $param_of },
                %{ $address },
            },
        } );
        my $ajax = new_ok( 'XTracker::Stock::Reservation::PreOrderAddressWS' => [ $mock_handler ] );
        my $output = $ajax->order_address_POST();

        $self->test_for_no_error_message( $output );

        if ( $test->{expect_warning} ) {
            is( $got_error_type, 'WARN', "Found a Warning" );
            like( $got_error_message, qr{WARNING.*State/County.*not one of}i,
                                "and the Warning is as Expected: '${got_error_message}'" );
        }
        else {
            ok( !defined $got_error_type, "No Warning Found" )
                                            or diag "Error Message: '${got_error_message}'";
        }
    }

    # restore the config's original setting
    $config->{countries_with_districts_for_ui}{country} = $orig_config_setting;

    # restore the Original 'xt_feeback' function
    no warnings 'redefine';
    *XTracker::Error::xt_feedback = $orig_xt_feedback;
    use warnings 'redefine';
}

sub test_create_pre_order_shipment_address_type : Tests() {
    my $self = shift(@_);
    $self->test_create_pre_order_address_for_addres_type($ADDRESS_TYPE__SHIPMENT);
}

sub test_create_pre_order_invoice_address_type : Tests() {
    my $self = shift(@_);
    $self->test_create_pre_order_address_for_addres_type($ADDRESS_TYPE__INVOICE);
}

sub test_create_pre_order_address_for_addres_type {
    my ($self, $address_type) = @_;

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {
            pre_order_id   => $self->{pre_order}->id,
            address_type   => $address_type,
            %{$self->{test_address}}
        }
    });

    my $ajax = new_ok('XTracker::Stock::Reservation::PreOrderAddressWS' => [$mock_handler]);
    my $output = $ajax->order_address_POST();

    if ($self->test_for_no_error_message($output)) {
        cmp_ok($output->{pre_order_id}, '==', $self->{pre_order}->id, 'Returned correct pre_order_id');

        foreach my $field (keys %{$self->{test_address}}) {
            is($output->{address}{$field}, $self->{test_address}{$field}, "Correct data retured for $field from ajax output");
        }

        my $address_from_database = $self->{schema}->resultset('Public::OrderAddress')->find($output->{address}{address_id});

        foreach my $field (keys %{$self->{test_address}}) {
            is($address_from_database->$field, $self->{test_address}{$field}, "Correct data retured for $field from database");
        }

    }
}

sub test_for_no_error_message {
    my ($self, $output) = @_;

    if ($output) {
        if (!exists($output->{errmsg})) {
            pass('No error message returned');
        }
        else {
            note 'Error message is '.$output->{errmsg};
        }
        cmp_ok($output->{ok}, '==', 1, 'Got Not  OK from ajax');
        return 1;
    }
    else {
        fail('No output from Ajax call');
        return 0;
    }
}

sub test_for_error_message {
    my ($self, $output, $errmsg) = @_;

    if ($output) {
        ok(exists($output->{errmsg}), 'Error message returned');
        cmp_ok($output->{ok}, '==', 0, 'Got Not  OK from ajax');
        if ( ref( $errmsg ) eq 'Regexp' ) {
            like($output->{errmsg}, $errmsg, 'Correct error message returned');
        } else {
            is($output->{errmsg}, $errmsg, 'Correct error message returned');
        }
    }
    else {
        fail('No output from Ajax call');
    }
}

sub teardown :Test(teardown) {
    my ($self) = @_;

    $self->SUPER::teardown();

    $self->{schema}->txn_rollback;
}

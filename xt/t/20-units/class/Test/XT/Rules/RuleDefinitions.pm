package Test::XT::Rules::RuleDefinitions;

use NAP::policy "tt", 'test';

use parent "NAP::Test::Class";

=head1 NAME

Test::XT::Rules::RuleDefinitions

=head1 SYNOPSIS

Tests the various Buisness Roles defined in 'XT::Rules::Definitions'.


*** Need to call this Class 'RuleDefinitions' because there is
    already a class in 't/lib' called 'Test::XT::Rules::Definitions'

=cut

use Test::XTracker::Data;
use XTracker::Constants::FromDB qw{ :department };
use XT::Rules::Solve;


# to be done first before ALL the tests start
sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{channel} = Test::XTracker::Data->channel_for_nap;
}

# to be done BEFORE each test runs
sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;
}

# to be done AFTER every test runs
sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}


=head1 TESTS

=head2 test_address__is_postcode_in_list_for_country

Tests the Definition 'Address::is_postcode_in_list_for_country' which returns TRUE
or FALSE based on whether a Post Code matches any from a list of Postcodes or parts
of a Postcode.

Based on the Country the postcodes are for effects how the postcode is taken apart
and how it is checked against those in the list.

=cut

sub test_address__is_postcode_in_list_for_country : Tests() {
    my $self    = shift;

    my $non_uk_country = $self->rs('Public::Country')->search( {
        country => { 'NOT IN' => [ 'Unknown', 'United Kingdom' ] },
    } )->first;
    my $uk_country     = $self->rs('Public::Country')->find( { country => 'United Kingdom' } );

    my @postcode_list = (
        'G1',
        'E',
        'GU',
        'G',
        'NW1',
        'NW3',
        '90210',
        '56432',
        'IP57SJ',
    );

    my @tests = (
        {
            postcodes   => [
                'G',
                'E',
                'nw1 1ww',
                'NW1 1WW',
                'gU111aH',
                'G1 1DF',
                'Nw3',
                'GU11',
            ],
            use_country => {
                'United Kingdom' => { country_rec => $uk_country,     expect_match => 1 },
            },
        },
        {
            postcodes   => [
                '',
                'NW23',
                'IP5 7SJ',
            ],
            use_country => {
                'United Kingdom' => { country_rec => $uk_country,     expect_match => 0 },
            },
        },
        {
            postcodes   => [
                '',
                'nw1 1ww',
                'NW1 1WW',
                'GU111AH',
                'G1 1DF',
            ],
            use_country => {
                'NON UK'         => { country_rec => $non_uk_country, expect_match => 0 },
            },
        },
        {
            postcodes   => [
                'nw2 1ww',
                'GD111AH',
                'H1 1DF',
                'NW',
            ],
            use_country => {
                'United Kingdom' => { country_rec => $uk_country,     expect_match => 0 },
                'NON UK'         => { country_rec => $non_uk_country, expect_match => 0 },
            },
        },
        {
            postcodes   => [
                'G1',
                'E',
                'gU',
                'G',
                'NW1',
                'nw3',
                '90210',
                '56432',
                'IP57SJ',
            ],
            use_country => {
                'NON UK'         => { country_rec => $non_uk_country, expect_match => 1 },
            },
        },
    );

    foreach my $test ( @tests ) {
        # check each postcode against each of the different countries specified
        foreach my $country ( keys %{ $test->{use_country} } ) {
            my $details   = $test->{use_country}{ $country };
            my @postcodes = @{ $test->{postcodes} };

            # set what should be expected for all postcodes
            my %expect = map {
                $_ => $details->{expect_match}
            } @{ $test->{postcodes} };

            my %got;
            foreach my $pcode ( @postcodes ) {
                $got{ $pcode } = XT::Rules::Solve->solve( 'Address::is_postcode_in_list_for_country' => {
                    country_id    => $details->{country_rec}->id,
                    postcode      => $pcode,
                    postcode_list => \@postcode_list,
                } );
            }

            cmp_deeply( \%got, \%expect,
                            "For Country: '${country}' got the Expected Matches for the Postcodes: (" . join( ',', @postcodes ) . ")" )
                                or diag "====> ERROR: Postcodes didn't Match as Expected - Got: " . p( %got ) .
                                               "\nExpected: " . p( %expect );
        }
    }
}

=head2 test_shipment__restrictions

Tests the 'Shipment::restrictions' definition. This just tests that it can be
called and the correct arguments can be passed for a detailed test on its use
see the test 't/20-units/class/Test/XTracker/Database/Shipment.pm'

=cut

sub test_shipment__restrictions : Tests() {
    my $self = shift;

    my $got;
    lives_ok {
        $got = XT::Rules::Solve->solve( 'Shipment::restrictions' => {
            product_ref => {},
            address_ref => {
                country      => '',
                country_code => '',
                sub_region   => '',
                county       => '',
                postcode     => '',
            },
            channel_id  => $self->{channel}->id,
            -schema     => $self->schema,
        } );
    } "Can solve 'Shipment::restrictions'";
    isa_ok( $got, 'HASH', "and return value as expected" );
}

=head2 test_shipment__exclude_shipping_charges_on_restrictions

Tests the 'Shipment::exclude_shipping_charges_on_restrictions' definition. This
just tests that it can be called and the correct arguments can be passed for a
detailed test on its use see the test 't/20-units/class/Test/XTracker/Database/Shipment.pm'

=cut

sub test_shipment__exclude_shipping_charges_on_restrictions : Tests() {
    my $self = shift;

    my $got;
    lives_ok {
        $got = XT::Rules::Solve->solve( 'Shipment::exclude_shipping_charges_on_restrictions' => {
            shipping_charges_ref => {},
            shipping_attributes  => {},
            always_keep_sku      => '',
            channel_id           => $self->{channel}->id,
        } );
    } "Can solve 'Shipment::exclude_shipping_charges_on_restrictions'";
    isa_ok( $got, 'HASH', "and return value as expected" );
}

=head2 test_shipment__get_allowed_value_of_shipment_signature_required_flag_for_address

Tests the 'Shipment::get_allowed_value_of_shipment_signature_required_flag_for_address' definition. This
test different scenario under which signature_required flag is SET when you update shipment address.

=cut

sub test_shipment__get_allowed_value_of_shipment_signature_required_flag_for_address : Tests() {
    my $self = shift;

    my %tests = (
        'Customer Care operator on DC1' => {
            expected => 1,
            setup => {
                DC => 'DC1',
                department_id => $DEPARTMENT__CUSTOMER_CARE,
                signature_required_flag => 1,
                address_ref  => {
                    'postcode' => 'd6a31',
                    'county' => 'London',
                    'country_code' => 'GB',
                    'sub_region' => 'EU Member States',
                    'country' => 'United Kingdom',
               }
            }
        },
        'Personal Shopping operator on DC1' => {
            expected => 1,
            setup => {
                DC => 'DC1',
                department_id => $DEPARTMENT__PERSONAL_SHOPPING,
                signature_required_flag => 0,
                address_ref  => {
                    'postcode' => 'd6a31',
                    'county' => 'NY',
                    'country_code' => 'GB',
                    'sub_region' => 'EU Member States',
                    'country'  => 'United Kingdom',
                },
            }
        },
        'Customer Care operator on DC2' => {
            expected => 0,
            setup => {
                DC => 'DC2',
                department_id => $DEPARTMENT__CUSTOMER_CARE,
                signature_required_flag => 0,
                address_ref  => {
                    'postcode' => 'd6a31',
                    'county' => 'NY',
                    'country_code' => 'US',
                    'sub_region' => 'North America',
                    'country' => 'United States',
               }
            }
        },
        'Shipping dept operator on DC1' => {
          expected => 0,
            setup => {
                DC => 'DC1',
                department_id => $DEPARTMENT__SHIPPING,
                signature_required_flag => 0,
                address_ref  => {
                    'postcode' => 'd6a31',
                    'county' => 'NY',
                    'country_code' => 'US',
                    'sub_region' => 'North America',
                    'country' => 'United States',
               }
            }
        },
        'Shipping dept operator on DC3' => {
          expected => 1,
            setup => {
                DC => 'DC3',
                department_id => $DEPARTMENT__SHIPPING,
                signature_required_flag => 1,
                address_ref  => {
                    'postcode' => 'd6a31',
                    'county' => 'NY',
                    'country_code' => 'US',
                    'sub_region' => 'North America',
                    'country' => 'United States',
               }
            }
        },
       'Customer Care operator on DC2 for United Kingdom'=> {
            expected => 1,
            setup => {
                DC => 'DC2',
                department_id => $DEPARTMENT__CUSTOMER_CARE,
                signature_required_flag => 0,
                address_ref  => {
                    'postcode' => 'd6a31',
                    'county' => 'London',
                    'country_code' => 'GB',
                    'sub_region' => 'EU Member States',
                    'country' => 'United Kingdom',
               }
            }
        },
    );


    foreach my $test_name ( keys %tests ) {
        note  "Tests : ${test_name}";

        my $test = $tests{$test_name};
        my $setup = $test->{setup};
        my $expect = $test->{expected};

        my $config  = \%XTracker::Config::Local::config;
        my $old_dc_setting = $config->{DistributionCentre}{name};
        $config->{DistributionCentre}{name} = $setup->{DC};

        my $got = XT::Rules::Solve->solve( 'Shipment::get_allowed_value_of_shipment_signature_required_flag_for_address' => {
            department_id           => $setup->{department_id},
            signature_required_flag => $setup->{signature_required_flag},
            address_ref             => $setup->{address_ref},
        });
        cmp_ok( $got,'==', $expect, " ${test_name} : Has correct output");

        #Reset the config value to original
        $config->{DistributionCentre}{name} =  $old_dc_setting;
    }
}


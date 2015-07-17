package Test::XTracker::Config::Local;
use NAP::policy qw/class test/;

BEGIN { extends "NAP::Test::Class" };

=head1 NAME

Test::XTracker::Config::Local

=head1 DESCRIPTION

Tests config functions in the 'XTracker::Config' module

=cut

use Test::XTracker::Data;
use Test::XTracker::LoadTestConfig;
use Test::Exception;

use Clone   qw( clone );

use XTracker::Config::Local qw(
    :carrier_automation
    order_nr_regex
    order_nr_regex_including_legacy
    address_formatting_messages_for_country
    dc_address
);


sub startup : Test( startup => no_plan ) {
    my $self = shift;

    # take a copy of the Config before all of the tests
    $self->{clone_config} = clone( \%XTracker::Config::Local::config );
}


sub setup : Test( setup => no_plan ) {
    my $self = shift;

    $self->schema->txn_begin;

}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;

    # restore the Config after each test
    %XTracker::Config::Local::config = %{ $self->{clone_config} };

    $self->schema->txn_rollback;

}

=head1 TESTS

=head2 test__get_packing_station_printers

=cut

sub test__get_packing_station_printers :Tests {
    my ($self) = @_;

    my $TEST_PREMIER_PACKING_STATION_NAME = 'TestStation';
    my $TEST_DOC_PRINTER_NAME = 'Test_Doc_Printer';
    my $TEST_CARD_PRINTER_NAME = 'Test_Card_Printer';

    # Create a fake packing station with only a doc and card printer
    my $test_pack_station = $self->schema->resultset('SystemConfig::ConfigGroup')->find_or_create({
        name => $TEST_PREMIER_PACKING_STATION_NAME
    });

    # Remove any printers that might already be there
    $test_pack_station->search_related('config_group_settings')->delete();

    $test_pack_station->create_related('config_group_settings', {
        setting => 'doc_printer', value => $TEST_DOC_PRINTER_NAME,
    });
    $test_pack_station->create_related('config_group_settings', {
        setting => 'card_printer', value => $TEST_CARD_PRINTER_NAME,
    });

    my $printers;
    lives_ok {
        $printers = get_packing_station_printers($self->schema(), $TEST_PREMIER_PACKING_STATION_NAME)
    } 'get_packing_station_printers() with test premier station but without premier flag lives';

    is_deeply($printers, { card => $TEST_CARD_PRINTER_NAME }, 'Only card printer returned');

    lives_ok {
        $printers = get_packing_station_printers($self->schema(), $TEST_PREMIER_PACKING_STATION_NAME, 1)
    } 'get_packing_station_printers() with test premier station and with premier flag lives';

    is_deeply($printers, {
        card => $TEST_CARD_PRINTER_NAME,
        document => $TEST_DOC_PRINTER_NAME
    }, 'card and document printer returned');

}

=head2 test_order_number_regex

Test the functions used to return the Order Number RegEx that
return valid patterns for Order Numbers in the DCs.

    order_nr_regex

=cut

sub test_order_number_regex : Tests() {
    my $self = shift;

    my $config = \%XTracker::Config::Local::config;

    my %tests = (
        "Simple Order Number RegEx String & Legacy RegEx String" => {
            # specify what the RegEx patterns should be for either
            # the 'regex' settings or the 'legacy_regex' settings
            setup => {
                regex        => '\d+',
                legacy_regex => '\d+-\d+',
            },
            # specify the Order Numbers to test with then
            # use either 1 or 0 to indicate whether they
            # should match the Order Number pattern returned
            # from the different functions or not
            order_numbers_to_test => {
                '12312314'  => { regex => 1, including_legacy_regex => 1 },
                '1231-2314' => { regex => 0, including_legacy_regex => 1 },
                'JCHGB0023' => { regex => 0, including_legacy_regex => 0 },
                'FG3335D23' => { regex => 0, including_legacy_regex => 0 },
            },
        },
        "Array of Order Number RegEx & Simple Legacy RegEx String" => {
            setup => {
                regex        => [
                    '\d+',
                    'JC[A-Z]+\d+',
                ],
                legacy_regex => '\d+-\d+',
            },
            order_numbers_to_test => {
                '12312314'  => { regex => 1, including_legacy_regex => 1 },
                '1231-2314' => { regex => 0, including_legacy_regex => 1 },
                'JCHGB0023' => { regex => 1, including_legacy_regex => 1 },
                'FG3335D23' => { regex => 0, including_legacy_regex => 0 },
            },
        },
        "Simple Order Number RegEx String & Array of Legacy RegEx" => {
            setup => {
                regex        => '\d+',
                legacy_regex => [
                    'JC[A-Z]+\d+',
                    '\d+-\d+',
                ],
            },
            order_numbers_to_test => {
                '12312314'  => { regex => 1, including_legacy_regex => 1 },
                '1231-2314' => { regex => 0, including_legacy_regex => 1 },
                'JCHGB0023' => { regex => 0, including_legacy_regex => 1 },
                'FG3335D23' => { regex => 0, including_legacy_regex => 0 },
            },
        },
        "Array of Order Number RegEx & Array of Legacy RegEx" => {
            setup => {
                regex        => [
                    '\d+',
                    '\d+-\d+-\d+',
                ],
                legacy_regex => [
                    'JC[A-Z]+\d+',
                    '\d+-\d+',
                ],
            },
            order_numbers_to_test => {
                '12312314'       => { regex => 1, including_legacy_regex => 1 },
                '1231-2314'      => { regex => 0, including_legacy_regex => 1 },
                '1231-2314-3245' => { regex => 1, including_legacy_regex => 1 },
                'JCHGB0023'      => { regex => 0, including_legacy_regex => 1 },
                'FG3335D23'      => { regex => 0, including_legacy_regex => 0 },
            },
        },
        "Order Number RegEx but NO Legacy RegEx" => {
            setup => {
                regex        => [
                    '\d+',
                    'JC[A-Z]+\d+',
                ],
            },
            order_numbers_to_test => {
                '12312314'  => { regex => 1, including_legacy_regex => 1 },
                '1231-2314' => { regex => 0, including_legacy_regex => 0 },
                'JCHGB0023' => { regex => 1, including_legacy_regex => 1 },
                'FG3335D23' => { regex => 0, including_legacy_regex => 0 },
            },
        },
        "NO Order Number RegEx but WITH Legacy RegEx" => {
            setup => {
                legacy_regex => [
                    '\d+',
                    'JC[A-Z]+\d+',
                ],
            },
            order_numbers_to_test => {
                '12312314'  => { regex => 0, including_legacy_regex => 1 },
                '1231-2314' => { regex => 0, including_legacy_regex => 0 },
                'JCHGB0023' => { regex => 0, including_legacy_regex => 1 },
                'FG3335D23' => { regex => 0, including_legacy_regex => 0 },
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test  = $tests{ $label };
        my $setup = $test->{setup};
        my $order_number_tests = $test->{order_numbers_to_test};

        # setup the Config Section to have the RegEx's that will be tested
        $config->{OrderNumber_RegEx} = $setup;

        # get the Patterns to match against for the different functions
        my $regex_pattern        = order_nr_regex() // '';
        my $legacy_regex_pattern = order_nr_regex_including_legacy();

        my %got;
        my %expect;

        while ( my ( $order_nr, $outcome ) = each %{ $order_number_tests } ) {
            $expect{ $order_nr } = $outcome;

            # call each function and store the result
            $got{ $order_nr } = {
                regex                  => ( $order_nr =~ m/\A${regex_pattern}\z/        ? 1 : 0 ),
                including_legacy_regex => ( $order_nr =~ m/\A${legacy_regex_pattern}\z/ ? 1 : 0 ),
            };
        }

        cmp_deeply( \%got, \%expect, "Order Numbers matched as Expected" )
                        or diag "ERROR - '${label}' - Order Numbers didn't match as Expected:\n" .
                                "Got: " . p( %got ) . "\n" .
                                "Expected: " . p( %expect );
    }
}

=head2 test_address_formatting_messages_for_country

Test the C<address_formatting_messages_for_country> method.

=cut

sub test_address_formatting_messages_for_country : Tests {
    my $self = shift;

    my $country_code            = 'GB';
    my $group_name              = 'AddressFormatingMessagesByCountry';
    my %setting_address_line_1  = ( setting => $country_code, value => 'address_line_1:Address Line One' );
    my %setting_address_line_2  = ( setting => $country_code, value => 'address_line_2:Address Line Two' );
    my %expected_address_line_1 = ( address_line_1 => 'Address Line One' );
    my %expected_address_line_2 = ( address_line_2 => 'Address Line Two' );

    my %tests = (
        'Missing Schema (no parameters)' => {
            parameters  => [],
            # Still ensure there is a setting, so we know the expected
            # response was not by accident.
            settings    => [ { %setting_address_line_1 } ],
            expected    => {},
            description => 'an empty HashRef',
        },
        'Missing Country Code (just schema parameter)' => {
            parameters  => [ $self->schema ],
            # Still ensure there is a setting, so we know the expected
            # response was not by accident.
            settings    => [ { %setting_address_line_1 } ],
            expected    => {},
            description => 'an empty HashRef',
        },
        'No Settings' => {
            parameters  => [ $self->schema, $country_code ],
            settings    => [],
            expected    => {},
            description => 'an empty HashRef',
        },
        'One Setting' => {
            parameters  => [ $self->schema, $country_code ],
            settings    => [ { %setting_address_line_1 } ],
            expected    => { %expected_address_line_1 },
            description => 'a HashRef with a single key/value',
        },
        'Two Settings' => {
            parameters  => [ $self->schema, $country_code ],
            settings    => [ { %setting_address_line_1 }, { %setting_address_line_2 } ],
            expected    => { %expected_address_line_1, %expected_address_line_2 },
            description => 'a HashRef with two keys/values',
        },
        'Duplicate Settings' => {
            parameters  => [ $self->schema, $country_code ],
            settings    => [ { %setting_address_line_1 }, { %setting_address_line_1 } ],
            expected    => { %expected_address_line_1 },
            description => 'a HashRef with a single key/value',
        },
    );

    while ( my ( $name, $test ) = each %tests ) {
        subtest $name => sub {

            my @parameters  = @{ $test->{parameters} };
            my @settings    = @{ $test->{settings} };
            my $expected    = $test->{expected};
            my $description = $test->{description};

            # Add a sequence to the settings.
            $settings[ $_ ]->{sequence} = $_ + 1
                foreach 0 .. $#settings;

            # Remove and re-create the Group and Settings.
            Test::XTracker::Data->remove_config_group( $group_name );
            Test::XTracker::Data->create_config_group( $group_name => { settings => \@settings } );

            cmp_deeply( address_formatting_messages_for_country( @parameters ),
                $expected,
                "The method returns $description" );

        }
    }

}


sub test__dc_address :Tests {
    my ($self) = @_;

    my @expected_keys = sort qw/addr1 addr2 addr3 postcode city country alpha-2/;

    my $channel = $self->schema->resultset('Public::Channel')->channel_list->first;

    my $address = dc_address($channel);

    my @actual_keys = sort keys %$address;

    eq_or_diff(\@actual_keys, \@expected_keys, 'Address keys are as expected');
}

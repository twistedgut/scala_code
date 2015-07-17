#!/usr/bin/env perl
# vim: ts=8 sts=4 et sw=4 sr sta
use NAP::policy "tt",     qw( test );

=head1 NAME

av_autofill_town.t

=head1 DESCRIPTION

Tests the Autofill Town Config and Autofill Address Validation City sections
for Address Validators.

For DHL this is in the '<DHL>' config and then within the sections called
'autofill_town_if_blank', which should be a Hash Ref. of Country Codes and '1'
to indicate that it can be used, and 'autofill_address_validation_city', which
should be a Hash Ref. of Country Codes and the default city to use for address
validation.


(currently only DHL is supported).

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];

BEGIN {
    use_ok('XTracker::Config::Local', qw(
                            config_var
                            can_autofill_town_for_address_validation
                            get_autofilled_town_for_address_validation
                        ));

    can_ok("XTracker::Config::Local", qw(
                            config_var
                            can_autofill_town_for_address_validation
                            get_autofilled_town_for_address_validation
                        ) );
}

# get a Hash of Country Codes keyed by Country Name
my $schema  = Test::XTracker::Data->get_schema;
my %country_codes = map {
    $_->country => $_->code,
} $schema->resultset('Public::Country')->all;

# define what to expect in the autofill_town_if_blank Config
my %dc_blank_tests   = (
    DC1 => {
        DHL => {
            $country_codes{'Hong Kong'}     => 1,
        },
    },
    DC2 => {
        DHL => {
            $country_codes{'Hong Kong'}     => 1,
        },
    },
    DC3 => {
        DHL => {
            $country_codes{'Hong Kong'}     => 1,
        },
    },
);

# define what to expect in the autofill_address_validation_city Config
my %dc_city_tests   = (
    DC1 => {
        DHL => {
            $country_codes{'Hong Kong'}     => 'Hong Kong',
        },
    },
    DC2 => {
        DHL => {
            $country_codes{'Hong Kong'}     => 'Hong Kong',
        },
    },
    DC3 => {
        DHL => {
            $country_codes{'Hong Kong'}     => 'Hong Kong',
        },
    },
);

my $blank_tests = $dc_blank_tests{ $distribution_centre };
my $city_tests = $dc_city_tests{ $distribution_centre };
if ( !$blank_tests && !$city_tests) {
    fail("No Tests defined for DC: '${distribution_centre}'");
    done_testing;
    exit;
}

### DHL ###

my $autofill_town_section = config_var( 'DHL', 'autofill_town_if_blank' );
my $autofill_address_city = config_var( 'DHL', 'autofill_address_validation_city' );

is_deeply( $autofill_town_section, $blank_tests->{DHL}, "'autofill_town_section' Config section is as expected" ) if $blank_tests;
is_deeply( $autofill_address_city, $city_tests->{DHL}, "'autofill_address_city' Config section is as expected" ) if $city_tests;

# go through each Country code and test the function
# 'can_autofill_town_for_address_validation' returns TRUE
# and get_autofilled_town_for_address_validation returns the
# expected city name
foreach my $code ( keys %{ $autofill_town_section } ) {
    note "Testing Country Code (can_autofill_town_for_address_validation): '${code}'";
    my $got = can_autofill_town_for_address_validation( 'DHL', $code );
    ok( defined $got, "'can_autofill_town_for_address_validation' returned a defined value" );
    cmp_ok( $got, '==', 1, "and the value is TRUE" );
}
foreach my $code ( keys %{ $autofill_address_city } ) {
    note "Testing Country Code (get_autofilled_town_for_address_validation): '${code}'";
    my $got_city = get_autofilled_town_for_address_validation( 'DHL', $code );
    ok( defined $got_city, "'get_autofilled_town_for_address_validation' returned a defined value" );
    cmp_ok( $got_city, 'eq', $autofill_address_city->{$code}, "and the value is as expected" );
}

### DHL ###


note "Test 'can_autofill_town_for_address_validation' returns FALSE";

my $got = can_autofill_town_for_address_validation( 'DHL', 'XX' );
ok( defined $got, "Returned a defined value when passing a nonsense Country Code" );
cmp_ok( $got, '==', 0, "and the value is FALSE" );

my $got_city = get_autofilled_town_for_address_validation( 'DHL', 'XX' );
ok( !defined $got_city, "Returned an undefined value when passing a nonsense Country Code" );

$got = can_autofill_town_for_address_validation( 'XXX', 'GB' );
ok( defined $got, "Returned a defined value when passing a nonsense Address Validator" );
cmp_ok( $got, '==', 0, "and the value is FALSE" );

$got_city = get_autofilled_town_for_address_validation( 'XXX', 'GB' );
ok( !defined $got_city, "Returned an undefined value when passing a nonsense Address Validator" );

done_testing;

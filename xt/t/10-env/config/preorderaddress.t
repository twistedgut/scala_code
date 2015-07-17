#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::RunCondition export => [ qw ( $distribution_centre ) ];

use XTracker::Config::Local qw(
    get_postcode_required_countries_for_preorder
    get_required_address_fields_for_preorder
);

=head1 NAME

t/10-env/config/preorderaddress.t

=head1 DESCRIPTION

This test checks that Countries, for which Postcode is a compulsary field, is setup correctly
for PreOrder functionality.

It also tests that the list of required fields for a Pre-Order is correct.

=cut

my %expected = (
    DC1 => {
        country => [ 'United States', 'United Kingdom' ],
        fields  => [ qw( first_name last_name address_line_1 towncity country ) ],
    },
    DC2 => {
        country => [ 'United States', 'United Kingdom' ],
        fields  => [ qw( first_name last_name address_line_1 towncity country ) ],
    },
    DC3 => {
        country => [ 'United States', 'United Kingdom' ],
        fields  => [ qw( first_name last_name address_line_1 towncity country ) ],
    }
);

if ( my $tests_for_dc = $expected{ $distribution_centre } ) {

    my $expected_countries  = $tests_for_dc->{country};
    my $expected_fields     = $tests_for_dc->{fields};

    my $countries   = get_postcode_required_countries_for_preorder();
    my $fields      = get_required_address_fields_for_preorder();

    isa_ok( $countries, 'ARRAY', 'get_postcode_required_countries_for_preorder' );
    cmp_deeply( $countries, $expected_countries, 'get_postcode_required_countries_for_preorder returns the correct list of countries' );

    isa_ok( $fields, 'ARRAY', 'get_required_address_fields_for_preorder' );
    cmp_deeply( $fields, $expected_fields, 'get_required_address_fields_for_preorder returns the correct list of fields' );

} else {

    fail( "Test is not setup for DC : ${distribution_centre}" );

}

done_testing;

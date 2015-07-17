#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head2 Checks functions/methods to do with Tax

This will test functions & methods that are to do with whether to apply/include Tax

* Tests the 'check_tax_included' function in 'XTracker::Database::Shipment'
* Tests the 'Shipment::tax_included' rule in 'XT::Rules::Definitions'

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ qw( $distribution_centre ) ];

use XTracker::Constants::FromDB         qw( :country :sub_region );
use XTracker::Database::Address         qw( get_country_data );


use_ok( 'XTracker::Database::Shipment', qw(
                                    check_tax_included
                                ) );
use_ok( 'XT::Rules::Solve' );

can_ok( 'XTracker::Database::Shipment', qw(
                                    check_tax_included
                                ) );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Sanity Check' );
my $dbh     = $schema->storage->dbh;


# lists all expected countries/regions
# that should have Tax included
my %expected    = (
    DC1 => {
        countries   => [
            $COUNTRY__UNITED_KINGDOM,
        ],
        regions     => [
            $SUB_REGION__EU_MEMBER_STATES,
        ],
    },
    DC2 => {
        countries   => [
            $COUNTRY__UNITED_STATES,
        ],
    },
    DC3 => {
        countries   => [
            $COUNTRY__HONG_KONG,
        ],
    },
);
my $expected_dc = $expected{ $distribution_centre };
if ( !$expected_dc ) {
    fail( "NO Expected Outcomes have been configured in this Test for DC: ${distribution_centre}" );
    done_testing;
    exit;
}

my $country_rs  = $schema->resultset('Public::Country');

# get a list of countries which
# we expect to have tax included
my $search_args = [];
if ( $expected_dc->{countries} ) {
    $search_args    = [ {
        id  => { 'IN' => $expected_dc->{countries} },
    } ];
}
if ( $expected_dc->{regions} ) {
    push @{ $search_args }, {
        sub_region_id => { 'IN' => $expected_dc->{regions} },
    };
}
my @tax_countries       = $country_rs->search( $search_args )->all;
my @non_tax_countries   = $country_rs->search( { id => { 'NOT IN' => [ map { $_->id } @tax_countries ] } } )->all;


# now go roud the NON Tax Countries & TAX Countries
# and check that we get the exepected results

note "checking NON Tax Included Countries";
foreach my $country ( @non_tax_countries ) {
    my $country_name= $country->country;
    my $country_rec = get_country_data( $schema, $country_name );
    my $got = check_tax_included( $dbh, $country_name );
    ok( defined $got && $got == 0, "${country_name}: 'check_tax_included' returned a defined value and is FALSE" );
    $got    = _tax_included_rule( $country_rec );
    ok( defined $got && $got == 0, "${country_name}: 'Shipment::tax_included' rule returned a defined value and is FALSE" );
}

note "checking Tax INCLUDED Countries";
foreach my $country ( @tax_countries ) {
    my $country_name= $country->country;
    my $country_rec = get_country_data( $schema, $country_name );
    my $got = check_tax_included( $dbh, $country_name );
    ok( defined $got && $got == 1, "${country_name}: 'check_tax_included' returned a defined value and is TRUE" );
    $got    = _tax_included_rule( $country_rec );
    ok( defined $got && $got == 1, "${country_name}: 'Shipment::tax_included' rule returned a defined value and is TRUE" );
}


done_testing;

#-------------------------------------------------------------------------

# wrapper around 'tax_included' rule
sub _tax_included_rule {
    my $country_rec = shift;

    return XT::Rules::Solve->solve(
        'Shipment::tax_included' => {
            country_record => $country_rec,
        }
    );
}

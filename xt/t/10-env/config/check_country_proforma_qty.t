#!/usr/bin/env perl
use NAP::policy "tt",     'test';

=head2 Checks the Number of Outward/Returns Proformas

This tests the Number of Outward and Returns Proformas that should be generated
per country when printing Shipping Documents.

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ qw( $distribution_centre ) ];

use XTracker::Constants::FromDB         qw( :country :sub_region );


# Defaults of how many proformas to expect
# for both Home & Foreign countries
my $EXPECTED_HOME_OUTWARD_QTY   = 0;
my $EXPECTED_HOME_RETURNS_QTY   = 1;
my $EXPECTED_FOREIGN_OUTWARD_QTY= 4;
my $EXPECTED_FOREIGN_RETURNS_QTY= 4;


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Sanity Check' );
my $dbh     = $schema->storage->dbh;


# lists all of the 'home' for the DC
# that should expect to have ZERO Outward
# Proformas and ONE Returns Proforma
my %dc_home_countries   = (
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
my $expected_home = $dc_home_countries{ $distribution_centre };
if ( !$expected_home ) {
    fail( "NO Expected Outcomes have been configured in this Test for DC: ${distribution_centre}" );
    done_testing;
    exit;
}

# list of exceptions to the expected qty defaults
my %exceptions  = (
    DC1 => {
        $COUNTRY__UNKNOWN           => { outward => 0, returns => 0 },
        $COUNTRY__AMERICAN_SAMOA    => { outward => 0, returns => 0 },
        $COUNTRY__FEDERATED_STATES_OF_MICRONESIA => { outward => 0, returns => 0 },
        $COUNTRY__GUERNSEY          => { returns => 1 },
        $COUNTRY__JERSEY            => { returns => 1 },
        $COUNTRY__KUWAIT            => { outward => 8 },
        $COUNTRY__MARSHALL_ISLANDS  => { outward => 0, returns => 0 },
        $COUNTRY__PALAU             => { outward => 0, returns => 0 },
        $COUNTRY__REUNION_ISLAND    => { outward => 0, returns => 0 },
        $COUNTRY__SOLOMON_ISLANDS   => { outward => 0, returns => 0 },
    },
    DC2 => {
        $COUNTRY__UNKNOWN           => { outward => 0, returns => 0 },
        $COUNTRY__AMERICAN_SAMOA    => { outward => 0, returns => 0 },
        $COUNTRY__BULGARIA          => { outward => 5 },
        $COUNTRY__FEDERATED_STATES_OF_MICRONESIA => { outward => 0, returns => 0 },
        $COUNTRY__MARSHALL_ISLANDS  => { outward => 0, returns => 0 },
        $COUNTRY__PALAU             => { outward => 0, returns => 0 },
        $COUNTRY__REUNION_ISLAND    => { outward => 0, returns => 0 },
        $COUNTRY__SOLOMON_ISLANDS   => { outward => 0, returns => 0 },
    },
    DC3 => {
        $COUNTRY__UNKNOWN           => { outward => 0, returns => 0 },
        $COUNTRY__KUWAIT            => { outward => 8 },
    },
);
my $dc_exceptions   = $exceptions{ $distribution_centre };

# get a list of countries which
# we expect to have tax included
my $country_rs  = $schema->resultset('Public::Country');
my $search_args = [];
if ( $expected_home->{countries} ) {
    $search_args    = [ {
        id  => { 'IN' => $expected_home->{countries} },
    } ];
}
if ( $expected_home->{regions} ) {
    push @{ $search_args }, {
        sub_region_id => { 'IN' => $expected_home->{regions} },
    };
}
my @home_countries      = $country_rs->search( $search_args )->all;
my @foreign_countries   = $country_rs->search( { id => { 'NOT IN' => [ map { $_->id } @home_countries ] } } )->all;


note "checking Foreign Countries";
foreach my $country ( @foreign_countries ) {
    my $country_name= $country->country;

    my $expected_outward    = $dc_exceptions->{ $country->id }{outward}
                                // $EXPECTED_FOREIGN_OUTWARD_QTY;
    my $expected_returns    = $dc_exceptions->{ $country->id }{returns}
                                // $EXPECTED_FOREIGN_RETURNS_QTY;

    cmp_ok( $country->proforma, '==', $expected_outward,
                "${country_name}: Outward Proforma Qty as expected: ${expected_outward}" );
    cmp_ok( $country->returns_proforma, '==', $expected_returns,
                "${country_name}: Returns Proforma Qty as expected: ${expected_returns}" );
}

note "checking Home Countries";
foreach my $country ( @home_countries ) {
    my $country_name= $country->country;

    my $expected_outward    = $dc_exceptions->{ $country->id }{outward}
                                // $EXPECTED_HOME_OUTWARD_QTY;
    my $expected_returns    = $dc_exceptions->{ $country->id }{returns}
                                // $EXPECTED_HOME_RETURNS_QTY;

    cmp_ok( $country->proforma, '==', $expected_outward,
                "${country_name}: Outward Proforma Qty as expected: ${expected_outward}" );
    cmp_ok( $country->returns_proforma, '==', $expected_returns,
                "${country_name}: Returns Proforma Qty as expected: ${expected_returns}" );
}


done_testing;

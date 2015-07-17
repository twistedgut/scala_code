#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => [ qw ( $distribution_centre ) ];

use XTracker::Config::Local;


my $schema = Test::XTracker::Data->get_schema;

my %expected_incorrect_countries = (
    DC1 => {
        country => [ 'United States', 'Hong Kong' ],
    },
    DC2 => {
        country => [ 'United Kingdom', 'Hong Kong' ],
    },
    DC3 => {
        country => [ 'United States', 'United Kingdom' ],
    }
);

my $unexpected_countries = $expected_incorrect_countries{ $distribution_centre };

if ( !$unexpected_countries ) {
    fail( "Test is not setup for DC : ${distribution_centre}" );
    done_testing;
    exit;
}

my $countries = config_var('IncorrectWebsiteCountry', 'country');

#make sure it is an array
if ( $countries && ref($countries) ne 'ARRAY' ) {
    $countries = [$countries];
}

is_deeply(
    [ sort grep { $_ } @{ $countries // [] } ],
    [ sort grep { $_ } @{ $unexpected_countries->{country} } ],
    "Correctly gives list of incorrect countries for Currenct DC"
);

done_testing;


#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use Test::XTracker::RunCondition export => [ '$distribution_centre' ];
use XTracker::Schema;
use XTracker::Database ':common';

ok(my $schema = get_database_handle(
        {
            name => 'xtracker_schema',
        }
    ),
    'should get XTracker schema');

my $loc_rs = $schema->resultset('Public::Location');
isa_ok($loc_rs, 'XTracker::Schema::ResultSet::Public::Location', 'location resultset');

my $loc_rsc = $loc_rs->result_class;
isa_ok($loc_rsc, 'XTracker::Schema::Result::Public::Location', 'location result class');

# check methods that exist on the resultset
can_ok(
    $loc_rsc,
    qw[
        parse_location_name
    ]
);

note 'Location Name Parsing';
{
    my %test_cases = (
        '012J079B' => {
            name => '012J079B',
            dc => '01',
            floor => '2',
            zone => 'J',
            number => '079',
            level => 'B',
        },
        '022F-1234A' => {
            name => '022F-1234A',
            dc => '02',
            floor => '2',
            zone => 'F',
            number => '1234',
            level => 'A',
        },
        'Quarantine' => {
            name => 'Quarantine',
        },
    );

    for my $test_case (sort keys %test_cases) {
        my $loc_components;
        lives_ok sub { $loc_components = $loc_rsc->parse_location_name($test_case) },
            'should parse location name without error';
        ok $loc_components, '  and should get a result';
        ok(ref $loc_components && ref $loc_components eq 'HASH', '  which should be a hashref');
        is_deeply($loc_components, $test_cases{$test_case}, '  and should match the expected output') or do {
            diag '*** parsed details returned:';
            diag p($loc_components, colored => !!$ENV{XT_DEBUG_COLOUR});
        };
    }
}

done_testing;

#!/usr/bin/perl

use NAP::policy "tt", 'test';
use SchemaTest;

my $schema_test = SchemaTest->new({
    dsn_from  => 'xtracker',
    namespace => 'XTracker::Schema',
    moniker   => 'Public::CountrySubdivision',
    glue      => 'Result',
});


$schema_test->methods( {
    columns => [
        qw[
            id
            country_id
            iso
            name
            country_subdivision_group_id
        ]
    ],

    relations => [
        qw[
            country
            country_subdivision_group
        ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);


$schema_test->run_tests();





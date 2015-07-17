#!/usr/bin/perl

use NAP::policy "tt", 'test';
use SchemaTest;

my $schema_test = SchemaTest->new({
    dsn_from  => 'xtracker',
    namespace => 'XTracker::Schema',
    moniker   => 'Public::CountrySubdivisionGroup',
    glue      => 'Result',
});


$schema_test->methods( {
    columns => [
        qw[
            id
            name
        ]
    ],
    relations => [
        qw[
            country_subdivisions
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
});


$schema_test->run_tests();





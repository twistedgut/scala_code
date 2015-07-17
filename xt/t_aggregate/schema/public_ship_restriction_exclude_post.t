#!/usr/bin/perl
use NAP::policy "tt", 'test';

use FindBin::libs;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::ShipRestrictionExcludePostcode',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                ship_restriction_id
                postcode
                country_id
            ]
        ],

        relations => [
            qw[
                country
                ship_restriction
            ]
        ],

        custom => [
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();


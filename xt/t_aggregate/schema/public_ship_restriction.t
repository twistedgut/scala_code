#!/usr/bin/perl
use NAP::policy "tt", 'test';

use FindBin::libs;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::ShipRestriction',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                title
                code
            ]
        ],

        relations => [
            qw[
                link_product__ship_restrictions
                ship_restriction_exclude_postcodes
                ship_restriction_allowed_countries
                ship_restriction_allowed_shipping_charges
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


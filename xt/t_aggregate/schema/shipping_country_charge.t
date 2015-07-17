#!/usr/bin/perl
use NAP::policy "tt", 'test';

# load the module that provides all of the common test functionality
use FindBin::libs;

#use Test::XTracker::Data;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Shipping::CountryCharge',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                charge
                currency_id
                country_id
                shipping_charge_id
            ]
        ],

        relations => [
            qw[
                shipping_charge
                country
                currency
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
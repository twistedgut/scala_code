#!/usr/bin/perl
use NAP::policy "tt", 'test';


# load the module that provides all of the common test functionality
use FindBin::libs;

use Test::XTracker::Data;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Shipping::Description',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                name
                public_name
                title
                public_title
                short_delivery_description
                long_delivery_description
                estimated_delivery
                delivery_confirmation
                shipping_charge_id
            ]
        ],

        relations => [
            qw[
                shipping_charge
            ]
        ],

        custom => [
            qw[
                broadcast
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();

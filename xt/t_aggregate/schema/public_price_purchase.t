#!/usr/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

# load the module that provides all of the common test functionality
use FindBin::libs;

use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::PricePurchase',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                product_id
                wholesale_price
                wholesale_currency_id
                original_wholesale
                uplift_cost
                uk_landed_cost
                uplift
                trade_discount
            ]
        ],

        relations => [
            qw[
                wholesale_currency
                product
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

$schematest->run_tests();

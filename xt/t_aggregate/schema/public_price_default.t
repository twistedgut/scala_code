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
        moniker   => 'Public::PriceDefault',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                product_id
                price
                currency_id
                complete
                complete_by_operator_id
                operator_id
                id
            ]
        ],

        relations => [
            qw[
                currency
                operator
                complete_by_operator
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

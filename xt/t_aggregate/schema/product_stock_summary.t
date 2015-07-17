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
        moniker   => 'Product::StockSummary',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                product_id
                ordered
                delivered
                main_stock
                sample_stock
                sample_request
                reserved
                pre_pick
                cancel_pending
                last_updated
                arrival_date
                channel_id
            ]
        ],

        relations => [
            qw[
                price_purchase
                product
                channel
                product_channel
            ]
# comment product_channel relationship out as Test::DBIx::Class::Schema
# can't handle the double column FK.
# uncomment when this is fixed - darius should be on the case.
#                product_channel
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

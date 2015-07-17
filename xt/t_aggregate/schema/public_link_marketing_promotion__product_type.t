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
        moniker   => 'Public::LinkMarketingPromotionProductType',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                marketing_promotion_id
                product_type_id
                include
            ]
        ],

        relations => [
            qw[
                marketing_promotion
                product_type
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                order_by_product_type
                get_included_product_types
            ]
        ],
    }
);

$schematest->run_tests();

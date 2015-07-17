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
        moniker   => 'Public::LinkMarketingPromotionCustomerCategory',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                marketing_promotion_id
                customer_category_id
                include
            ]
        ],

        relations => [
            qw[
                marketing_promotion
                customer_category
            ]
        ],

        custom => [
            qw[
            ]
        ],

        resultsets => [
            qw[
                order_by_customer_category
                get_included_customer_categories
            ]
        ],
    }
);

$schematest->run_tests();

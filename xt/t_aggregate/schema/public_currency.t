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
        moniker   => 'Public::Currency',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                currency
            ]
        ],

        relations => [
            qw[
                countries
                customer_credits
                orders
                price_countries
                price_defaults
                price_purchases
                price_regions
                purchase_orders
                renumerations
                sales_conversion_rate_destination_currencies
                sales_conversion_rate_source_currencies
                super_purchase_orders
                pre_orders
                shipping_charges
                returns_charges
                country_charges
                region_charges
                voucher_purchase_orders
                voucher_products
                promotion_details
            ]
        ],

        custom => [
            qw[
                conversion_rate_to
                get_glyph_html_entity
            ]
        ],

        resultsets => [
            qw[
                find_by_name
            ]
        ],
    }
);

$schematest->run_tests();


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
        moniker   => 'Voucher::Product',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                operator_id
                channel_id
                created
                landed_cost
                value
                visible
                currency_id
                is_physical
                disable_scheduled_update
                upload_date
            ]
        ],

        relations => [
            qw[
                operator
                currency
                channel
                stock_orders
                variant
                codes
            ]
        ],

        custom => [
            qw[
                get_three_images
                sku
                size_id
                size
                designer_size
                variants
                live
                arrival_date
                add_code
                weight
                designer
                fabric_content
                country_of_origin
                hs_code
                shipping_attributes
                storage_type_id
                storage_type
                is_on_sale
                season_id
                season
                delivery_logs
                get_product_channel
                get_saleable_item_quantity_rs
                get_saleable_item_quantity
                colour
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();

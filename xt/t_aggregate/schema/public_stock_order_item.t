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
        moniker   => 'Public::StockOrderItem',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                stock_order_id
                variant_id
                quantity
                status_id
                type_id
                cancel
                original_quantity
                voucher_variant_id
                stock_order_item_cancel
            ]
        ],

        relations => [
            qw[
                link_delivery_item__stock_order_items
                status
                stock_order
                type
                variant
                delivery_items
                voucher_variant
                product_variant
                voucher_codes
            ]
        ],

        custom => [
            qw[
                check_status
                variant
                get_delivered_quantity
                is_cancelled
                is_delivered
            ]
        ],

        resultsets => [
            qw[
            ]
        ],
    }
);

$schematest->run_tests();

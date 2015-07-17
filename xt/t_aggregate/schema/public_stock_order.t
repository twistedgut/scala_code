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
        moniker   => 'Public::StockOrder',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                product_id
                purchase_order_id
                start_ship_date
                cancel_ship_date
                status_id
                comment
                type_id
                consignment
                cancel
                confirmed
                shipment_window_type_id
                voucher_product_id
                stock_order_cancel
            ]
        ],

        relations => [
            qw[
                link_delivery__stock_orders
                status
                type
                stock_order_items
                public_product
                voucher_product
                shipment_window_type
                deliveries
                purchase_order
            ]
        ],

        custom => [
            qw[
                check_status
                update_status
                can_create_packing_slip
                why_cannot_create_packing_slip
                product
                product_channel
                quantity_ordered
                originally_ordered
                quantity_delivered
                create_delivery
                get_voucher_codes
            ]
        ],

        resultsets => [
            qw[
                get_undelivered_stock
            ]
        ],
    }
);

$schematest->run_tests();

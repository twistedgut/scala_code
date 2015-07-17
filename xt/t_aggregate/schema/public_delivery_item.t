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
        moniker   => 'Public::DeliveryItem',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                delivery_id
                packing_slip
                quantity
                status_id
                type_id
                cancel
                last_updated
            ]
        ],

        relations => [
            qw[
                type
                delivery
                status
                link_delivery_item__quarantine_processes
                link_delivery_item__shipment_items
                link_delivery_item__stock_order_items
                stock_processes
                link_delivery_item__return_item
                stock_order_items
                rma_request_details
                rtv_quantities
            ]
        ],

        custom => [
            qw[
                get_shipment_item
                get_return_item
                stock_order_item
                update_status
                is_status_valid
                is_item_count_valid
                is_cancelled
                stock_process
                stock_processes_complete
                complete
            ]
        ],

        resultsets => [
            qw[
                search_new_items
                prefetch_stock_order_items
                prefetch_variants
                uncancelled
            ]
        ],
    }
);

$schematest->run_tests();


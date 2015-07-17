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
        moniker   => 'Public::Delivery',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                date
                invoice_nr
                status_id
                type_id
                cancel
                on_hold
                last_updated
            ]
        ],

        relations => [
            qw[
                status
                type
                delivery_items
                delivery_notes
                link_delivery__return
                link_delivery__shipments
                link_delivery__stock_order
                log_deliveries
                link_delivery__shipment
            ]
        ],

        custom => [
            qw[
                shipment
                stock_order
                create_note
                order_by_created
                hold
                release
                create_delivery_items
                get_total_packing_slip
                get_total_quantity
                log_stock_in
                log_item_count
                log_bag_and_tag
                is_priority
                is_cancelled
                delivery_items_complete
                complete
                mark_as_counted
                ready_for_qc
                is_voucher_delivery
                create_delivery_item
                is_processing
                is_complete
                has_been_qced
                cancel_delivery
            ]
        ],

        resultsets => [
            qw[
                get_held_deliveries
                get_delivery_order
                get_deliveries_by_status
                get_deliveries_by_channel
                for_item_count
                for_qc
                get_delivery_data_by_status
                recent_deliveries
                order_by_oldest
            ]
        ],
    }
);

$schematest->run_tests();


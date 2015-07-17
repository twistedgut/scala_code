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
        moniker   => 'Public::Variant',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                product_id
                size_id_old
                nap_size_id
                legacy_sku
                type_id
                size_id
                designer_size_id
                std_size_id
                vtype
            ]
        ],

        relations => [
            qw[
                channel_transfer_picks
                channel_transfer_putaways
                log_rtv_stocks
                orphan_items
                quarantine_processes
                return_items
                shipment_items
                stock_count_variants
                stock_order_items
                stock_transfers
                size
                designer_size
                product
                std_size
                variant_measurements
                quantities
                rtv_quantities
                log_pws_stocks
                log_locations
                stock_consistencies
                reservation_consistencies
                variant_measurements_logs
                reservations
                third_party_sku
                stock_recodes
                log_pws_reservation_corrections
                pre_order_items
                putaway_prep_inventories
                outer_product
                rma_request_details
                log_putaway_discrepancies
            ]
        ],

        custom => [
            qw[
                sku
                quantity_on_channel
                picked_shipment_items_on_channel
                stock_transfers_on_channel
                current_stock_on_channel
                current_channel
                selected
                selected_for_sample
                update_pws_quantity
                large_label
                small_label
            ]
        ],

        resultsets => [
            qw[
                get_variant_measurements
                get_stock_variants_by_product
                search_by_sku
                find_by_sku
                dispatched_sample_quantities
                lost_sample_shipment_items
                get_variants_for_designer
                get_variant_ids_for_designer
            ]
        ],
    }
);

$schematest->run_tests();

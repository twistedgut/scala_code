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
        moniker   => 'Voucher::Variant',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                voucher_product_id
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
                product
                quantities
                locations
                log_rtv_stocks
                log_pws_stocks
                shipment_items
                log_locations
                orphan_items
                stock_order_items
                putaway_prep_inventories
            ]
        ],

        custom => [
            qw[
                sku
                size_id
                size
                designer_size
                quantity_on_channel
                picked_shipment_items_on_channel
                stock_transfers_on_channel
                current_stock_on_channel
                product_id
                current_channel
                selected
                selected_for_sample
                update_pws_quantity
            ]
        ],

        resultsets => [
            qw[
                find_by_sku
            ]
        ],
    }
);

$schematest->run_tests();

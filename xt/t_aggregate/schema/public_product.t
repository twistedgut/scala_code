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
        moniker   => 'Public::Product',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                world_id
                designer_id
                division_id
                classification_id
                product_type_id
                sub_type_id
                colour_id
                style_number
                season_id
                hs_code_id
                operator_id
                note
                legacy_sku
                colour_filter_id
                payment_term_id
                payment_settlement_discount_id
                payment_deposit_id
                watch
                storage_type_id
                operator_id
                canonical_product_id
            ]
        ],

        relations => [
            qw[
                classification
                colour
                colour_filter
                designer
                product_type
                season
                price_purchase
                stock_order
                stock_orders
                price_default
                attribute
                product_attribute
                product_channel
                product_channel_upload
                variants
                show_measurements
                stock_summary
                attribute_value
                pws_sort_order
                shipping_attribute
                hs_code
                sub_type
                recommended_master_products
                recommended_products
                price_adjustments
                price_region
                price_country
                storage_type
                channel_transfers
                outer_storage_type
                outer_designer
                external_image_urls
                link_product__ship_restrictions
                audit_recents
                contents
                division
                world
                pws_sort_orders
                navigation_trees
                promotion_detail_products
                promotion_detail_product
            ]
        ],

        custom => [
            qw[
                name
                get_three_images
                has_stock
                location_info
                sample_location_info
                get_colour_variations
                is_on_sale
                requires_measuring
                has_product_type_of
                get_product_channel
                get_saleable_item_quantity_rs
                get_saleable_item_quantity
                get_stock_variants
                preorder_name
                has_ship_restriction
                small_labels_per_item
                large_labels_per_item
                hide_measurement
                show_measurement
                show_default_measurements
                add_volumetrics
            ]
        ],

        resultsets => [
            qw[
                get_promotion_products
            ]
        ],
    }
);

$schematest->run_tests();

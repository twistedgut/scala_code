#!/usr/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;


# load the module that provides all of the common test functionality
use FindBin::libs;
use Test::More;
use Test::XTracker::Data;    # preloading
use SchemaTest;



my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::Channel',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                business_id
                distrib_centre_id
                web_name
                is_enabled
                timezone
                company_registration_number
                default_tax_code
                colour_detail_override
                idx
                has_public_website
            ]
        ],

        relations => [
            qw[
                boxes
                bulk_reimbursements
                carrier_box_weights
                business
                channel_brandings
                channel_transfer_from_channel_ids
                channel_transfer_to_channel_ids
                country_shipment_types
                country_shipping_charges
                country_tax_codes
                credit_hold_thresholds
                customers
                customer_credits
                designer_channels
                hotlist_values
                inner_boxes
                log_locations
                log_pws_stocks
                log_rtv_stocks
                log_sample_adjustments
                log_stocks
                operator_preferences
                orders
                product_channels
                product_type_measurements
                promotion_types
                purchase_orders
                quantities
                quarantine_processes
                recommended_products
                reservations
                reservation_consistencies
                sample_classification_default_sizes
                sample_product_type_default_sizes
                sample_size_scheme_default_sizes
                shipping_accounts
                shipping_account__countries
                stock_transfers
                super_purchase_orders
                distrib_centre
                config_group
                config_groups
                designers
                reservation_consistencies
                stock_consistencies
                correspondence_subjects
                routing_exports
                postcode_shipping_charges
                log_pws_reservation_corrections
                marketing_promotions
                packaging_attributes
                shipping_charges
                marketing_customer_segments
                fraud_archived_rules
                fraud_live_rules
                fraud_staging_rules
                log_rule_engine_switch_positions
                link_manifest__channels
                rma_requests
                log_putaway_discrepancies
                pages
                transfers
                stock_summaries
                state_shipping_charges
                rtv_shipments
                rtv_quantities
                log_designer_descriptions
                returns_charges
                voucher_purchase_orders
                voucher_products
                designer_attributes
                log_website_states
                product_attributes
                pws_sort_orders
            ]
        ],

        custom => [
            qw[
                lc_web_name
                web_queue_name_part
                carrier_automation_state
                carrier_automation_is_on
                carrier_automation_is_off
                carrier_automation_import_off
                is_on_mrp
                is_on_nap
                is_on_outnet
                is_on_jc
                has_welcome_pack
                is_config_group_active
                is_on_dc1
                is_on_dc2
                is_on_dc3
                is_on_dc
                find_promotion_type_for_country
                find_welcome_pack_for_language
                find_promotion_types_for_language
                short_name
                is_fulfilment_only
                is_above_no_delivery_signature_threshold
                can_auto_upload_reservations
                can_communicate_to_customer_by
                can_premier_send_alert_by
                premier_hold_alert_threshold
                get_correspondence_subject
                pws_dbh
                refresh_stock_consistency
                saleable_stock_by_sku
                saleable_inventory_for_all_stock
                stock_manager
                refresh_reservation_consistency
                reservations_by_sku
                has_nominated_day_shipping_charges
                has_customer_facing_premier_shipping_charges
                is_fraud_rules_engine_on
                is_fraud_rules_engine_off
                is_fraud_rules_engine_in_parallel
                should_not_recalc_shipping_cost_for_customer_class
                welcome_pack_product_type_exclusion
                can_apply_pre_order_discount
                get_customer_category_pre_order_discount
                get_pre_order_system_config
                get_can_send_shipment_updates
            ]
        ],

        resultsets => [
            qw[
                channel_list
                get_channels_rs
                drop_down_options
                fulfilment_only
                enabled
                enabled_channels
                get_channels
                get_channel
                get_channel_details
                get_channel_config
                find_by_web_name
                find_by_name
                enabled_channels_with_public_website
            ]
        ],
    }
);



my $schema = Test::XTracker::Data->get_schema;


note "*** website_name";
my $channel_row = $schema->resultset("Public::Channel")->search({
    web_name => { like => "OUTNET%" },
})->first;
like(
    $channel_row->website_name,
    qr/^OUT_\w+$/,
    "website_name is well formed",
);

is($channel_row->config_name, 'OUTNET', 'Config name is correct');

$schematest->run_tests();

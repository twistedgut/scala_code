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
        moniker   => 'Promotion::Detail',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                created
                created_by
                last_modified
                last_modified_by
                visible_id
                internal_title
                start_date
                end_date
                target_city_id
                enabled
                discount_type
                discount_percentage
                discount_pounds
                discount_euros
                discount_dollars
                coupon_prefix
                coupon_target_id
                coupon_restriction_id
                coupon_generation_id
                price_group_id
                basket_trigger_pounds
                basket_trigger_euros
                basket_trigger_dollars
                title
                subtitle
                status_id
                been_exported
                exported_to_lyris
                restrict_by_weeks
                restrict_x_weeks
                coupon_custom_limit
                event_type_id
                publish_method_id
                publish_date
                announce_date
                close_date
                publish_to_announce_visibility
                announce_to_start_visibility
                start_to_end_visibility
                end_to_close_visibility
                target_value
                target_currency
                product_page_visible
                end_price_drop_date
                description
                dont_miss_out
                sponsor_id
                is_classic
            ]
        ],

        relations => [
            qw[
                target_city
                event_type
                detail_seasons
                seasons
                detail_designers
                designers
                detail_producttypes
                producttypes
                detail_products
                products
                detail_customers
                detail_customergroups
                customergroups
                detail_customergroup_joins
                coupon_target
                coupon_restriction
                coupon_generation
                detail_websites
                websites
                detail_shippingoptions
                shipping_options
                coupons
                status
                publish_method
                last_modified_by
                price_group
                target_currency
                announce_to_start_visibility_obj
                publish_to_announce_visibility_obj
                start_to_end_visibility_obj
                detail_product
                end_to_close_visibility_obj
                created_by
            ]
        ],

        custom => [
            qw[
                can_export
                applicable_customer_list
                applicable_product_list
                customergroup_included_id_list
                customergroup_excluded_id_list
                customers_of_type
                designer_id_list
                disable
                exclude_group_join
                excluded_customers
                expects_product_restrictions
                export_coupons
                export_customers
                export_customers_to_pws
                export_promo_products_to_pws
                export_to_lyris
                export_to_pws
                freeze_customers_in_groups
                frozen_customers
                generate_coupons
                generate_specific_coupons
                generic_coupon
                group_join_type
                has_coupon_codes
                has_custom_coupon_limit
                include_group_join
                included_customers
                is_active
                is_generic_coupon
                is_specific_coupon
                is_outnet_event
                producttype_id_list
                promotion_product_pid_list
                pws_info
                requires_customer_freeze
                requires_emails
                season_id_list
                shipping_id_list
                status_coupons_generated
                status_coupons_generating
                status_customer_list_frozen
                status_disabled
                status_exported
                status_exported_to_lyris
                status_exporting_to_lyris
                status_exporting_anything
                status_exporting_to_pws
                status_in_progress
                status_job_failed
                status_job_queued
                website_id_list
            ]
        ],

        resultsets => [
            qw[
                promotion_list
                retrieve_promotion
                retrieve_event
                pws_get_export_promos
                have_been_exported
            ]
        ],
    }
);

$schematest->run_tests();

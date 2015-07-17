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
        moniker   => 'Public::Customer',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                is_customer_number
                title
                first_name
                last_name
                email
                category_id
                created
                modified
                telephone_1
                telephone_2
                telephone_3
                group_id
                ddu_terms_accepted
                legacy_comment
                credit_check
                no_marketing_contact
                no_signature_required
                channel_id
                prev_order_count
                correspondence_default_preference
                account_urn
            ]
        ],

        relations => [
            qw[
                channel
                category
                customer_attribute
                customer_credit
                customer_credit_logs
                customer_notes
                orders
                reservations
                customer_correspondence_method_preferences
                customer_csm_preferences
                customer_flags
                pre_orders
                link_marketing_customer_segment__customers
                customer_actions
                customer_service_attribute_logs
            ]
        ],

        custom => [
            qw[
                pws_customer_id
                display_name
                is_category_eip_premium
                is_category_eip
                is_an_eip
                is_category_ip
                is_category_hot_contact
                is_category_staff
                customers_with_same_email
                has_finance_watch_flag
                reservations_by_variant_id
                related_orders_in_status
                credit_check_orders
                credit_hold_orders
                orders_aged
                add_order
                change_csm_preference
                csm_preferences_rs
                get_csm_preferences
                get_csm_available_to_change
                ui_change_csm_available_by_subject
                can_use_csm
                csm_prefs_allow_method
                csm_default_prefs_allow_method
                set_language_preference
                get_language_preference
                locale
                is_on_other_channels
                customer_class_id
                orders_within_period_not_cancelled
                orders_aged_on_any_channel
                total_spend_in_last_n_period
                total_spend_in_last_n_period_on_all_channels
                has_new_high_value_action
                set_new_high_value_action
                should_not_have_shipping_costs_recalculated
                calculate_customer_value
                get_customer_value_from_service
                update_customer_value_in_service
                get_pre_order_discount_percent
                get_local_addresses
                get_seaview_or_local_addresses
            ],
            # from Role 'Schema::Role::CustomerHierarchy'
            qw[
                next_in_hierarchy
                next_in_hierarchy_isa
                next_in_hierarchy_from_class
                next_in_hierarchy_with_method
            ]
        ],

        resultsets => [
            qw[
                search_by_pws_customer_nr
            ]
        ],
    }
);

$schematest->run_tests();

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
        moniker   => 'Public::Operator',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                name
                username
                password
                auto_login
                disabled
                department_id
                email_address
                phone_ddi
                use_ldap
                last_login
                use_acl_for_main_nav
            ]
        ],

        relations => [
            qw[
                department
                operator_preference
                customer_notes
                permissions
                operator_role
                log_shipment_signature_requireds
                sent_messages
                received_messages
                reservations
                shipment_message_logs
                variant_measurements_logs
                reservation_operator_log_operator
                reservation_operator_log_to_operator
                reservation_operator_log_from_operator
                sticky_page
                pre_orders
                pre_order_applied_discounts
                order_email_logs
                fraud_change_logs
                fraud_archived_rules_created
                fraud_archived_rules_expired
                fraud_archived_conditions_created
                fraud_archived_conditions_expired
                fraud_archived_lists_created
                fraud_archived_lists_expired
                log_rule_engine_switch_positions
                customer_actions
                log_welcome_pack_changes
                operator_authorisations
                shipment_hold_logs
                shipment_item_container_logs
                correspondence_templates_logs
                address_change_logs
                allocation_item_logs
                bulk_reimbursements
                channel_transfer_picks
                channel_transfer_putaways
                customer_credit_logs
                delivery_date_restriction_logs
                delivery_notes_created
                delivery_notes_modified
                ip_address_lists
                log_channel_transfers
                log_deliveries
                log_locations
                log_payment_fulfilled_changes
                log_payment_preauth_cancellations
                log_pws_stocks
                log_rtv_stocks
                log_shipment_rtcb_states
                log_stocks
                marketing_customer_segment_logs
                marketing_customer_segments
                marketing_promotion_logs
                marketing_promotions
                order_address_logs
                order_notes
                order_status_logs
                orphan_items
                pre_order_email_logs
                pre_order_item_status_logs
                pre_order_notes
                pre_order_operator_log_from_operator
                pre_order_operator_log_operator
                pre_order_operator_log_to_operator
                pre_order_refund_failed_logs
                pre_order_refund_status_logs
                pre_order_status_logs
                price_defaults
                published_logs
                purchase_orders
                putaway_prep_containers
                renumeration_change_logs
                renumeration_status_logs
                reservation_auto_change_logs
                reservation_logs
                return_arrivals
                return_delivery_created_bies
                return_delivery_operator_ids
                return_email_logs
                return_item_status_logs
                return_notes
                return_status_logs
                rma_request_detail_status_logs
                rma_requests
                routing_export_status_logs
                rtv_inspection_pick_requests
                rtv_shipment_status_logs
                shipment_address_logs
                shipment_box_logs
                shipment_email_logs
                shipment_extra_items
                shipment_holds
                shipment_item_status_logs
                shipment_notes
                shipment_status_logs
                shipping_attributes
                shipping_attribute_packing_notes
                transfers
                web_content_instances_created
                web_content_instances_last_updated
                log_designer_descriptions
                log_replaced_payment_preauth_cancellations
                log_replaced_payment_fulfilled_changes
                manifest_status_logs
                voucher_purchase_orders
                voucher_products
                designer_log_attribute_values
                product_log_attribute_values
                navigation_tree_locks
                log_navigation_trees
                log_website_states
                promotion_details_last_modified
                promotion_customer_customergroups_modified
                promotion_customer_customergroups_created
                promotion_details_created
                recent_audits
                dbadmin_log_back_fill_job_runs
                dbadmin_log_back_fill_job_statuses
            ]
        ],

        custom => [
            qw[
                initials
                customer_ref
                send_message
                check_if_has_role
                is_manager
                is_operator
                is_read_only
                has_location_for_section
                create_orders_search_by_designer_file_name
                create_completed_orders_search_by_designer_results_file
            ]
        ],

        resultsets => [
            qw[
                get_operator
                operator_list
                get_operator_by_username
                by_authorisation
                in_department
                with_live_reservation
                parse_orders_search_by_designer_file_name
                get_list_of_search_orders_by_designer_result_files
                get_list_of_search_orders_by_designer_result_files_for_view
                read_search_orders_by_designer_result_file
                process_search_orders_by_designer_result_file_contents
                process_search_orders_by_designer_result_file_contents_for_json
            ]
        ],
    }
);

$schematest->run_tests();

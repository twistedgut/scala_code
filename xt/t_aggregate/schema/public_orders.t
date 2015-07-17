#!/usr/bin/perl
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

# load the module that provides all of the common test functionality
use FindBin::libs;
use Test::XTracker::Data;    # preloading
use Test::More;
use SchemaTest;

my $schematest = SchemaTest->new(
    {
        dsn_from  => 'xtracker',
        namespace => 'XTracker::Schema',
        moniker   => 'Public::Orders',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                order_nr
                basket_nr
                invoice_nr
                session_id
                cookie_id
                date
                total_value
                gift_credit
                store_credit
                customer_id
                invoice_address_id
                credit_rating
                card_issuer
                card_scheme
                card_country
                card_hash
                cv2_response
                order_status_id
                email
                telephone
                mobile_telephone
                comment
                currency_id
                use_external_tax_rate
                used_stored_card
                channel_id
                ip_address
                placed_by
                sticker
                pre_auth_total_value
                last_updated
                customer_language_preference_id
                order_created_in_xt_date
            ]
        ],

        relations => [
            qw[
                link_orders__shipments
                order_flags
                order_promotions
                currency
                invoice_address
                channel
                order_status_logs
                order_address
                order_notes
                order_status
                customer
                tenders
                payment
                payments
                order_attribute
                orders_csm_preferences
                order_channel
                address_change_logs
                order_address_logs
                link_bulk_reimbursement__orders
                link_orders__pre_orders
                link_orders__marketing_promotions
                customer_language_preference
                order_email_logs
                customer_language_preference
                remote_dc_query
                orders_rule_outcome
                remote_dc_queries
                replaced_payments
                card_payment
                payment
            ]
        ],

        custom => [
            qw[
                new
                add_to_shipments
                shipments
                get_standard_class_shipment
                make_order_status_message
                get_vouchers_by_code_id
                voucher_value_used
                voucher_tenders
                store_credit_tender
                paid_by
                was_a_card_used
                renumerations
                refund_renumerations
                payment_renumerations
                tender_count
                voucher_only_order
                cancel_payment_preauth
                add_note
                is_beyond_valid_payments_threshold
                invalidate_order_payment
                validate_order_payment
                is_in_credit_check
                change_csm_preference
                csm_preferences_rs
                get_csm_preferences
                get_csm_available_to_change
                ui_change_csm_available_by_subject
                can_use_csm
                csm_prefs_allow_method
                get_phone_number
                is_on_credit_hold
                is_accepted
                card_debit_tender
                order_check_payment
                has_marketing_promotion
                get_all_marketing_promotions
                is_customers_nth_order
                payment_card_type
                payment_card_avs_response
                is_payment_card_new_for_customer
                has_payment_card_been_used_before
                contains_a_voucher
                contains_a_virtual_voucher
                is_in_hotlist
                should_put_onhold_for_signature_optout_for_standard_class_shipment
                get_psp_info
                clear_method_cache
                has_flag
                accept_or_hold_order_after_fraud_check
                get_total_value
                get_total_value_in_local_currency
                get_original_total_value_in_local_currency
                is_paid_using_third_party_psp
                is_paid_using_credit_card
                is_paid_using_the_third_party_psp
                get_third_party_payment_method
                contains_sale_shipment
                payment_method_insists_billing_and_shipping_address_always_the_same
                payment_method_allows_editing_of_billing_address
                payment_method_requires_basket_updates
                payment_method_allows_full_refund_using_only_store_credit
                payment_method_allows_full_refund_using_only_the_payment
                is_staff_order
                cancel_payment_preauth_and_delete_payment
                payment_method_allows_pure_goodwill_refunds
                payment_method_requires_payment_cancelled_if_forced_shipping_address_updated_used
                cancel_payment_preauth_and_invalidate_payment
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
                get_order_billing_details
                not_cancelled
                get_search_results_by_shipment_id_rs
            ]
        ],
    }
);

$schematest->run_tests();

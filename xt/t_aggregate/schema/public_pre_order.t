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
        moniker   => 'Public::PreOrder',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                customer_id
                pre_order_status_id
                reservation_source_id
                reservation_type_id
                shipment_address_id
                invoice_address_id
                shipping_charge_id
                packaging_type_id
                currency_id
                operator_id
                telephone_day
                telephone_eve
                total_value
                comment
                created
                signature_required
                applied_discount_percent
                applied_discount_operator_id
                last_updated
            ]
        ],

        relations => [
            qw[
                currency
                customer
                invoice_address
                packaging_type
                pre_order_email_logs
                pre_order_items
                pre_order_notes
                pre_order_payment
                pre_order_refunds
                pre_order_status
                pre_order_status_logs
                pre_order_operator_logs
                reservation_source
                reservation_type
                shipment_address
                operator
                shipping_charge
                link_orders__pre_orders
                applied_discount_operator
            ]
        ],

        custom => [
            qw[
                can_confirm_all_items
                confirm_all_items
                select_all_items
                complete_all_items
                is_cancelled
                is_complete
                is_payment_declined
                is_cancelled
                is_part_exported
                is_exported
                is_notifiable
                notify_web_app
                update_status
                get_payment
                cancel
                all_items_are_cancelled
                total_uncancelled_value
                total_uncancelled_value_formatted
                pre_order_number
                channel
                has_shipment_address_change
                update_from_vertex_quotation
                create_vertex_quotation_request
                create_vertex_quotation
                get_item_shipping_attributes
                get_total_without_discount
                get_total_without_discount_formatted
                has_discount
            ],
            # from Role 'Schema::Role::Hierarchy'
            qw[
                next_in_hierarchy
                next_in_hierarchy_isa
                next_in_hierarchy_from_class
                next_in_hierarchy_with_method
            ]
        ],

        resultsets => [
            qw[
                  complete
                  incomplete
                  exported
                  cancelled
                  part_exported
                  payment_declined
                  not_complete
                  not_incomplete
                  not_exported
                  not_cancelled
                  not_part_exported
                  not_payment_declined
                  are_all_complete
                  are_all_incomplete
                  are_all_exported
                  are_all_cancelled
                  are_all_part_exported
                  are_all_payment_declined
                  order_by_id
                  order_by_id_desc
                  order_by_created
                  order_by_created_desc
                  for_customer_id
                  for_currency_id
            ]
        ],
    }
);

$schematest->run_tests();

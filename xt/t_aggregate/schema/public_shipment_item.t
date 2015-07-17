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
        moniker   => 'Public::ShipmentItem',
        glue      => 'Result',
    }
);
$schematest->methods(
    {
        columns => [
            qw[
                id
                shipment_id
                variant_id
                unit_price
                tax
                duty
                shipment_item_status_id
                special_order_flag
                shipment_box_id
                voucher_code_id
                pws_ol_id
                gift_from
                gift_to
                gift_message
                voucher_variant_id
                qc_failure_reason
                container_id
                gift_recipient_email
                last_updated
                is_incomplete_pick
                lost_at_location_id
                returnable_state_id
                sale_flag_id
            ]
        ],

        relations => [
            qw[
                allocation_items
                cancelled_item
                link_delivery_item__shipment_items
                link_shipment_item__price_adjustment
                link_shipment_item__promotion
                renumeration_items
                return_item_shipment_item_ids
                return_item_exchange_shipment_item_ids
                shipment
                variant
                container
                shipment_item_container_logs
                shipment_item_status
                shipment_box
                shipment_item_status_logs
                return_items
                voucher_code
                voucher_variant
                link_shipment_item__reservations
                link_shipment_item__reservation_by_pids
                lost_at_location
                returnable_state
                sale_flag
            ]
        ],

        custom => [
            qw[
                return_item
                update_status
                set_returned
                set_dispatched
                set_cancelled
                set_cancel_pending
                can_cancel
                cancel
                set_lost
                set_selected
                validate_pick_into
                validate_packing_exception_into
                pick_into
                packing_exception_into
                orphan_item_into
                unpick
                product_id
                product
                has_been_picked
                is_pre_picked
                is_pre_picking_commenced
                is_being_picked
                is_pre_dispatch
                date_dispatched
                website_status
                last_location
                get_true_variant
                is_voucher
                is_physical_voucher
                is_virtual_voucher
                refund_invoice_total
                unassign_and_deactivate_voucher_code
                voucher_usage
                get_channel
                is_qc_failed
                is_missing
                get_sku
                get_product_id
                packing_exception_operator
                cancel_and_move_stock_to_iws_location
                relationships_for_signature
                is_discounted
                purchase_price
                is_new
                is_selected
                is_cancelled
                is_cancel_pending
                is_picked
                is_packed
                is_returned
                is_lost
                selected_outside_of_shipment
                sample_selected_outside_of_shipment
                get_reservation_to_link_to
                get_preorder_reservation_to_link_to
                is_returnable_on_pws
                get_reservation_to_link_to_by_pid
                is_linked_to_reservation
                check_for_and_assign_reservation
            ]
        ],

        resultsets => [
            qw[
                shipment_item_picking_date
                not_cancelled
                cancelled
                not_cancel_pending
                cancel_pending
                qc_failed
                missing
                are_all_new
                unpick
                pick_into
                find_by_sku
                order_by_sku
                search_by_sku
                search_by_sku_and_item_status
                items_in_container
                check_voucher_code
                container_ids
                containers
                pre_picking
                selected
                transfer_shipments
                exclude_vouchers
            ]
        ],
    }
);

$schematest->run_tests();

package XTracker::BuildConstants;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Data::Dump qw( pp );
use Template;

use XTracker::Database;


# EVIL GLOBAL VARIABLES!
my ($dbh, $ttdata);

our @constant_data_list = (
    {
        name            => 'premier_routing',
        table_name      => 'premier_routing',
        id_column       => 'id',
        name_column     => 'code',
    },
    {
        name            => 'std_size',
        table_name      => 'std_size',
        id_column       => 'id',
        name_column     => 'name',
    },
    {
        name            => 'channel',
        table_name      => 'channel',
        id_column       => 'id',
        name_column     => 'web_name',
        no_dash         => 1,
    },
    {
        name            => 'business',
        table_name      => 'business',
        id_column       => 'id',
        name_column     => 'config_section',
    },
    {
        name            => 'client',
        table_name      => 'client',
        id_column       => 'id',
        name_column     => 'prl_name',
    },
    {
        name            => 'distrib_centre',
        table_name      => 'distrib_centre',
        id_column       => 'id',
        name_column     => 'name',
    },
    {
        name            => 'authorisation_level',
        table_name      => 'authorisation_level',
        id_column       => 'id',
        name_column     => 'description',
    },
    {
        name            => 'authorisation_section',
        table_name      => 'authorisation_section',
        id_column       => 'id',
        name_column     => 'section',
    },
    {
        name            => 'customer_category',
        table_name      => 'customer_category',
        id_column       => 'id',
        name_column     => 'category',
    },
    {
        name            => 'customer_class',
        table_name      => 'customer_class',
        id_column       => 'id',
        name_column     => 'class',
    },

    {
        name            => 'correspondence_templates',
        table_name      => 'correspondence_templates',
        id_column       => 'id',
        name_column     => 'name',
        name_column2    => 'department_id',
    },
    {
        name            => 'country',
        table_name      => 'country',
        id_column       => 'id',
        name_column     => 'country',
    },
    {
        name            => 'delivery_action',
        table_name      => 'delivery_action',
        id_column       => 'id',
        name_column     => 'action',
    },
    {
        name            => 'delivery_type',
        table_name      => 'delivery_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'delivery_status',
        table_name      => 'delivery_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'delivery_item_type',
        table_name      => 'delivery_item_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'delivery_item_status',
        table_name      => 'delivery_item_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'department',
        table_name      => 'department',
        id_column       => 'id',
        name_column     => 'department',
    },
    {
        name            => 'order_status',
        table_name      => 'order_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name             => 'packing_exception_action',
        table_name       => 'packing_exception_action',
        id_column        => 'id',
        name_column      => 'name',
        build_value_list => 1,
    },
    {
        name            => 'region',
        table_name      => 'region',
        id_column       => 'id',
        name_column     => 'region',
    },
    {
        name            => 'renumeration_class',
        table_name      => 'renumeration_class',
        id_column       => 'id',
        name_column     => 'class',
    },
    {
        name            => 'renumeration_status',
        table_name      => 'renumeration_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'renumeration_type',
        table_name      => 'renumeration_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'return_status',
        table_name      => 'return_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'return_item_status',
        table_name      => 'return_item_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'return_type',
        table_name      => 'return_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name             => 'shipment_item_status',
        table_name       => 'shipment_item_status',
        id_column        => 'id',
        name_column      => 'status',
        build_value_list => 1,
    },
    {
        name             => 'fulfilment_overview_stage',
        table_name       => 'fulfilment_overview_stage',
        id_column        => 'id',
        name_column      => 'stage',
    },
    {
        name            => 'shipment_status',
        table_name      => 'shipment_status',
        id_column       => 'id',
        name_column     => 'status',
        build_value_list=> 1,
    },
    {
        name            => 'shipment_type',
        table_name      => 'shipment_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'shipment_class',
        table_name      => 'shipment_class',
        id_column       => 'id',
        name_column     => 'class',
    },
    {
        name            => 'shipping_charge_class',
        table_name      => 'shipping_charge_class',
        id_column       => 'id',
        name_column     => 'class',
    },
    {
        name            => 'ship_restriction',
        table_name      => 'ship_restriction',
        id_column       => 'id',
        name_column     => 'code',
    },
    {
        name            => 'shipment_window_type',
        table_name      => 'shipment_window_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'stock_transfer_type',
        table_name      => 'stock_transfer_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'stock_transfer_status',
        table_name      => 'stock_transfer_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'sub_region',
        table_name      => 'sub_region',
        id_column       => 'id',
        name_column     => 'sub_region',
    },
    # Return to Vendor
    {
        name            => 'rma_request_status',
        table_name      => 'rma_request_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'rma_request_detail_status',
        table_name      => 'rma_request_detail_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'rma_request_detail_type',
        table_name      => 'rma_request_detail_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'rtv_shipment_status',
        table_name      => 'rtv_shipment_status',
        id_column       => 'id',
        name_column     => 'status',
            # comical schema - "I'm reference the status field in the status
            # table" I think they mean status.(name/label)
                # Sincere apologies. The schema police should bang me up and throw away the primary key :-| #TJG
    },
    {
        name            => 'rtv_shipment_detail_status',
        table_name      => 'rtv_shipment_detail_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'rtv_inspection_pick_request_status',
        table_name      => 'rtv_inspection_pick_request_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'rtv_shipment_detail_result_type',
        table_name      => 'rtv_shipment_detail_result_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'rtv_action',
        table_name      => 'rtv_action',
        id_column       => 'id',
        name_column     => 'action',
    },
    {
        name            => 'item_fault_type',
        table_name      => 'item_fault_type',
        id_column       => 'id',
        name_column     => 'fault_type',
    },
    ###
    {
        name            => 'upload_status',
        table_name      => 'upload_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'variant_type',
        table_name      => 'variant_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'flag',
        table_name      => 'flag',
        id_column       => 'id',
        name_column     => 'description',
    },
    {
        name            => 'flag_type',
        table_name      => 'flag_type',
        id_column       => 'id',
        name_column     => 'description',
    },
    # sample request detail status
    {
        name            => 'sample_request_det_status',
        table_name      => 'sample_request_det_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    # stock process
    {
        name            => 'stock_process_type',
        table_name      => 'stock_process_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'stock_process_status',
        table_name      => 'stock_process_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'stock_action',
        table_name      => 'stock_action',
        id_column       => 'id',
        name_column     => 'action',
    },
    {
        name            => 'pws_action',
        table_name      => 'pws_action',
        id_column       => 'id',
        name_column     => 'action',
        build_value_list=> 1,
    },
    {
        name            => 'reservation_status',
        table_name      => 'reservation_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    # CANDO-696
    {
        name            => 'reservation_source',
        table_name      => 'reservation_source',
        id_column       => 'id',
        name_column     => 'source',
    },
    #from the upload schema
    {
        name            => 'upload_transfer_status',
        table_name      => 'upload.transfer_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'upload_transfer_log_action',
        table_name      => 'upload.transfer_log_action',
        id_column       => 'id',
        name_column     => 'log_action',
    },
    # from the product schema
    {
        name            => 'product_attribute_type',
        table_name      => 'product.attribute_type',
        id_column       => 'id',
        name_column     => 'name',
    },
    # from the web content schema
    {
        name            => 'page_instance_status',
        table_name      => 'web_content.instance_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'web_content_field',
        table_name      => 'web_content.field',
        id_column       => 'id',
        name_column     => 'name',
    },
    {
        name            => 'web_content_type',
        table_name      => 'web_content.type',
        id_column       => 'id',
        name_column     => 'name',
    },
    {
        name            => 'web_content_template',
        table_name      => 'web_content.template',
        id_column       => 'id',
        name_column     => 'name',
    },
    # from the designer schema
    {
        name            => 'designer_attribute_type',
        table_name      => 'designer.attribute_type',
        id_column       => 'id',
        name_column     => 'name',
    },
    {
        name            => 'designer_website_state',
        table_name      => 'designer.website_state',
        id_column       => 'id',
        name_column     => 'state',
    },
    # from the event schema
    {
            name            => 'event_type',
            table_name      => 'event.type',
            id_column       => 'id',
            name_column     => 'name',
    },
    {
            name            => 'event_product_visibility',
            table_name      => 'event.product_visibility',
            id_column       => 'id',
            name_column     => 'name',
    },
    # from the promotion schema
    {
        name            => 'promotion_coupon_generation',
        fake_table_name => 'promotion.coupon_generation',
        table_name      => 'event.coupon_generation',
        id_column       => 'id',
        name_column     => 'action',
    },
    {
        name            => 'promotion_coupon_target',
        fake_table_name => 'promotion.coupon_target',
        table_name      => 'event.coupon_target',
        id_column       => 'id',
        name_column     => 'description',
    },
    {
        name            => 'promotion_website',
        fake_table_name => 'promotion.website',
        table_name      => 'event.website',
        id_column       => 'id',
        name_column     => 'name',
    },
    {
        name            => 'promotion_jointype',
        fake_table_name => 'promotion.detail_customergroup_join',
        table_name      => 'event.detail_customergroup_join',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'promotion_customergrouptype',
        fake_table_name => 'promotion.customergroup_listtype',
        table_name      => 'event.customergroup_listtype',
        id_column       => 'id',
        name_column     => 'name',
    },
    {
        name            => 'promotion_status',
        fake_table_name => 'promotion.status',
        table_name      => 'event.status',
        id_column       => 'id',
        name_column     => 'name',
    },
    {
        name            => 'promotion_price_group',
        fake_table_name => 'promotion.price_group',
        table_name      => 'event.price_group',
        id_column       => 'id',
        name_column     => 'description',
    },
    {
        name            => 'promotion_shipping_option',
        fake_table_name => 'promotion.shipping_option',
        table_name      => 'event.shipping_option',
        id_column       => 'id',
        name_column     => 'name',
    },
    # stock counting
    {
        name            => 'stock_count_origin',
        table_name      => 'stock_count_origin',
        id_column       => 'id',
        name_column     => 'origin',
    },
    {
        name            => 'stock_count_status',
        table_name      => 'stock_count_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    # stock order
    {
        name            => 'stock_order_status',
        table_name      => 'stock_order_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'stock_order_type',
        table_name      => 'stock_order_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'stock_order_item_status',
        table_name      => 'stock_order_item_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'stock_order_item_type',
        table_name      => 'stock_order_item_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'shipment_hold_reason',
        table_name      => 'shipment_hold_reason',
        id_column       => 'id',
        name_column     => 'reason',
    },
    {
        name            => 'recommended_product_type',
        table_name      => 'recommended_product_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'price_adjustment_category',
        table_name      => 'price_adjustment_category',
        id_column       => 'id',
        name_column     => 'category',
    },
    {
        name            => 'cancel_reason',
        table_name      => 'cancel_reason',
        id_column       => 'id',
        name_column     => 'reason',
    },
    {
        name            => 'customer_issue_type_group',
        table_name      => 'customer_issue_type_group',
        id_column       => 'id',
        name_column     => 'description',
    },
    {
        name            => 'customer_issue_type',
        table_name      => 'customer_issue_type',
        id_column       => 'id',
        name_column     => 'group_id',
        name_column2    => 'description',
    },
    {
        name            => 'carrier',
        table_name      => 'carrier',
        id_column       => 'id',
        name_column     => 'name',
    },
    {
        name            => 'channel_transfer_status',
        table_name      => 'channel_transfer_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'product_channel_transfer_status',
        table_name      => 'product_channel_transfer_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'note_type',
        table_name      => 'note_type',
        id_column       => 'id',
        name_column     => 'description',
    },
    {
        name            => 'purchase_order_status',
        table_name      => 'purchase_order_status',
        id_column       => 'id',
        name_column     => 'status',
    },
    {
        name            => 'purchase_order_type',
        table_name      => 'purchase_order_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'currency',
        table_name      => 'currency',
        id_column       => 'id',
        name_column     => 'currency',
    },
    {
        name            => 'season',
        table_name      => 'season',
        id_column       => 'id',
        name_column     => 'season',
    },
    {
        name            => 'segment',
        table_name      => 'segment',
        id_column       => 'id',
        name_column     => 'segment',
    },
    {
        name            => 'segment_type',
        table_name      => 'segment_type',
        id_column       => 'id',
        name_column     => 'type',
    },
    {
        name            => 'season_act',
        table_name      => 'season_act',
        id_column       => 'id',
        name_column     => 'act',
    },

    # from the flow schema - uses a join!
    {
        name            => 'flow_status',
        table_name      => 'flow.status',
        id_column       => 'id',
        name_column     => 'name',
        join => {
            name_column => 'name',
            table_name  => 'flow.type',
            join_column => 'type_id',
            id_column   => 'id',
        },
    },
    {
        name        => 'flow_type',
        table_name  => 'flow.type',
        id_column   => 'id',
        name_column => 'name',
    },

    {
        name        => 'storage_type',
        table_name  => 'product.storage_type',
        id_column   => 'id',
        name_column => 'name',
    },

    {
        name        => 'container_status',
        table_name  => 'public.container_status',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'manifest_status',
        table_name  => 'public.manifest_status',
        id_column   => 'id',
        name_column => 'status',
    },
    #promotion_classes - to give a class to a 'promotion_type'
    {
        name        => 'promotion_class',
        table_name  => 'promotion_class',
        id_column   => 'id',
        name_column => 'class',
    },
    # reimbursements
    {
        name        => 'bulk_reimbursement_status',
        table_name  => 'bulk_reimbursement_status',
        id_column   => 'id',
        name_column => 'status',
    },
    # refund_charge_type
    {
        name        => 'refund_charge_type',
        table_name  => 'refund_charge_type',
        id_column   => 'id',
        name_column => 'type',
    },
    # branding for Sales Channels
    {
        name        => 'branding',
        table_name  => 'branding',
        id_column   => 'id',
        name_column => 'code',
    },
    # routing_schedule_type
    {
        name        => 'routing_schedule_type',
        table_name  => 'routing_schedule_type',
        id_column   => 'id',
        name_column => 'name',
    },
    # routing_schedule_type
    {
        name        => 'routing_schedule_status',
        table_name  => 'routing_schedule_status',
        id_column   => 'id',
        name_column => 'name',
    },
    # correspondence_method
    {
        name        => 'correspondence_method',
        table_name  => 'correspondence_method',
        id_column   => 'id',
        name_column => 'method',
    },
    # routing export_status
    {
        name        => 'routing_export_status',
        table_name  => 'routing_export_status',
        id_column   => 'id',
        name_column => 'status',
    },
    # sms_correspondence_status
    {
        name        => 'sms_correspondence_status',
        table_name  => 'sms_correspondence_status',
        id_column   => 'id',
        name_column => 'status',
    },
    # CANDO-696
    {
        name        => 'pre_order_status',
        table_name  => 'pre_order_status',
        id_column   => 'id',
        name_column => 'status',
    },
    # CANDO-696
    {
        name        => 'pre_order_item_status',
        table_name  => 'pre_order_item_status',
        id_column   => 'id',
        name_column => 'status',
    },
    # CANDO-696
    {
        name        => 'pre_order_note_type',
        table_name  => 'pre_order_note_type',
        id_column   => 'id',
        name_column => 'description',
    },
    # CANDO-734: Cancelling/Refunding Pre-Order
    {
        name        => 'pre_order_refund_status',
        table_name  => 'pre_order_refund_status',
        id_column   => 'id',
        name_column => 'status',
    },
    # putaway_prep_container_status
    {
        name        => 'putaway_prep_container_status',
        table_name  => 'putaway_prep_container_status',
        id_column   => 'id',
        name_column => 'status',
    },
    # putaway_prep_group_status
    {
        name        => 'putaway_prep_group_status',
        table_name  => 'putaway_prep_group_status',
        id_column   => 'id',
        name_column => 'status',
    },
    # from the shipping schema
    {
        name            => 'shipping_delivery_date_restriction_type',
        table_name      => 'shipping.delivery_date_restriction_type',
        id_column       => 'id',
        name_column     => 'name',
    },
    {
        name            => 'putaway_type',
        table_name      => 'putaway_type',
        id_column       => 'id',
        name_column     => 'name',
    },

    # Allocation Item Statuses
    {
        name         => 'allocation_item_status',
        table_name   => 'allocation_item_status',
        id_column    => 'id',
        name_column  => 'status',
    },
    # Allocation Statuses
    {
        name         => 'allocation_status',
        table_name   => 'allocation_status',
        id_column    => 'id',
        name_column  => 'status',
    },
    # DCA-956 - induction
    {
        name        => 'physical_place',
        table_name  => 'physical_place',
        id_column   => 'id',
        name_column => 'name',
    },
    # CANDO-1485: Bulk Order Action
    {
        name         => 'bulk_order_action',
        table_name   => 'bulk_order_action',
        id_column    => 'id',
        name_column  => 'name',
    },
    # WHM-1900: Pack Lane Attributes
    {
        name         => 'pack_lane_attribute',
        table_name   => 'pack_lane_attribute',
        id_column    => 'pack_lane_attribute_id',
        name_column  => 'name',
    },
    # CANDO-2156: Security List Status
    {
        name        => 'security_list_status',
        table_name  => 'security_list_status',
        id_column   => 'id',
        name_column => 'status',
    },
    # CANDO-2116 for Fraud Rules:
    {
        name        => 'fraud_rule_status',
        table_name  => 'fraud.rule_status',
        id_column   => 'id',
        name_column => 'status',
    },
    {
        name        => 'fraud_rule_outcome_status',
        table_name  => 'fraud.rule_outcome_status',
        id_column   => 'id',
        name_column => 'status',
    },
    # CANDO-2474: 'New High Value' marketing flag.
    {
        name        => 'customer_action_type',
        table_name  => 'public.customer_action_type',
        id_column   => 'id',
        name_column => 'type',
    },
    # CANDO-2198: Welcome Pack changes
    {
        name        => 'welcome_pack_change',
        table_name  => 'welcome_pack_change',
        id_column   => 'id',
        name_column => 'change',
    },
    # CANDO-367: Renumeration Reason Types
    {
        name        => 'renumeration_reason_type',
        table_name  => 'renumeration_reason_type',
        id_column   => 'id',
        name_column => 'type',
    },
      # CANDO-1199: Hotlist Types
    {
        name        => 'hotlist_field',
        table_name  => 'hotlist_field',
        id_column   => 'id',
        name_column => 'field',
    },
    {
        name        => 'shipping_class',
        table_name  => 'shipping_class',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'shipping_direction',
        table_name  => 'shipping_direction',
        id_column   => 'id',
        name_column => 'name',
    },
     # WHM-2947 - SOS tables
    {
        name        => 'sos_shipment_class',
        table_name  => 'sos.shipment_class',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'sos_shipment_class_attribute',
        table_name  => 'sos.shipment_class_attribute',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'sos_week_day',
        table_name  => 'sos.week_day',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'sos_country',
        table_name  => 'sos.country',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'sos_channel',
        table_name  => 'sos.channel',
        id_column   => 'id',
        name_column => 'name',
    },
    # CANDO-2885: Shipment Item Returnable States
    {
        name        => 'shipment_item_returnable_state',
        table_name  => 'shipment_item_returnable_state',
        id_column   => 'id',
        name_column => 'state',
    },
    # CANDO-2910: 'orders.payment_method_class'
    {
        name        => 'orders_payment_method_class',
        table_name  => 'orders.payment_method_class',
        id_column   => 'id',
        name_column => 'payment_method_class',
    },
    # CANDO-2910: 'orders.internal_third_party_status'
    {
        name        => 'orders_internal_third_party_status',
        table_name  => 'orders.internal_third_party_status',
        id_column   => 'id',
        name_column => 'status',
    },
    {
        name        => 'prl',
        table_name  => 'prl',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'prl_speed',
        table_name  => 'prl_speed',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'prl_pack_space_allocation_time',
        table_name  => 'prl_pack_space_allocation_time',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'prl_pack_space_unit',
        table_name  => 'prl_pack_space_unit',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'prl_pick_trigger_method',
        table_name  => 'prl_pick_trigger_method',
        id_column   => 'id',
        name_column => 'name',
    },
    {
        name        => 'prl_delivery_destination',
        table_name  => 'prl_delivery_destination',
        id_column   => 'id',
        name_column => 'name',
    },
    # CANDO-7911: 'orders.internal_third_party_status'
    {
        name        => 'service_attribute_type',
        table_name  => 'service_attribute_type',
        id_column   => 'id',
        name_column => 'type',
    },
    # Integration item statuses (only used for GOH+DCD integration
    # in PRL phase 2 so far)
    {
        name         => 'integration_container_item_status',
        table_name   => 'integration_container_item_status',
        id_column    => 'id',
        name_column  => 'status',
    },
    # CANDO-7942: Shipment Item On Sale Flag
    {
        name        => 'shipment_item_on_sale_flag',
        table_name  => 'shipment_item_on_sale_flag',
        id_column   => 'id',
        name_column => 'flag',
    },
    # CANDO-8651: Back-Fill Job Status
    {
        name        => 'dbadmin_back_fill_job_status',
        table_name  => 'dbadmin.back_fill_job_status',
        id_column   => 'id',
        name_column => 'status',
    },
);

################################################################################

    sub new {
        my ($proto, $options) = @_;
        my $class = ref($proto) || $proto;
        my $self = bless {}, $class;

        $self->{ttdata} = undef;

        # We need to explicitly specify a DBI connect_object here as to load
        # DBIC files we need the Constants file, which is generated by this
        # module.
        $self->{dbh}    = XTracker::Database::db_connection({
            name => 'xtracker', autocommit => 1, connect_object => 'DBI',
        }) unless $options->{no_connect};
        $self->{constant_data_list} = \@constant_data_list;

        return $self;
    }

    sub prepare_constants {
        my $self          = shift;
        my $constant_data = $self->{constant_data_list};

        foreach my $data ( @{$constant_data} ) {
            $self->add_constant_group(
                {
                    name             => $data->{name},
                    table_name       => $data->{table_name},
                    fake_table_name  => $data->{fake_table_name},
                    id_column        => $data->{id_column},
                    name_column      => $data->{name_column},
                    name_column2     => $data->{name_column2},
                    join             => $data->{join},
                    no_dash          => $data->{no_dash},
                    build_value_list => $data->{build_value_list},
                }
            );
        }
    }

    sub add_constant_group {
        my $self    = shift;
        my $options = shift;

        push @{ $self->{ttdata}->{constant_group} },
            {
                name => $options->{name},
                data => $self->constants_from_table({
                    table_name      => $options->{table_name},
                    fake_table_name => $options->{fake_table_name},
                    id_column       => $options->{id_column},
                    name_column     => $options->{name_column},
                    name_column2    => $options->{name_column2},
                    join            => $options->{join},
                    no_dash         => $options->{no_dash},
                }),
                build_value_list => $options->{build_value_list},
            }
        ;
    }

    sub spit_out_template {
        my ($self, $file) = @_;
        my ($ttdata) = $self->{ttdata};
        my ($template, $fh);


        NO_STRICT_REFS: {
            no strict 'refs'; ## no critic(ProhibitNoStrict)
            $fh = \*{ __PACKAGE__ . '::DATA' }
        }

        $template = Template->new() or die $!;

        if ($file) {
            # write parsed template to a file
            $template->process($fh, $ttdata, $file)
                or die $template->error() . "\n";
        }
        else {
            # spam to STDOUT
            $template->process($fh, $ttdata)
                or die $template->error() . "\n";
        }
    }

    sub constants_from_table {
        my $self    = shift;
        my $options = shift;
        my ($dbh, $sql, $sth, $res);
        my @constant_list;

        # readonly DB access
        $dbh = $self->{dbh};

        # build the SQL
        if (defined $options->{join}) {
            my $join = $options->{join};

            $sql = qq[
                SELECT  self.$options->{id_column}      AS id_col,
                        self.$options->{name_column}    AS name_col,
                        other.$join->{name_column}      AS name_col2
                  FROM  $options->{table_name} self
                        LEFT JOIN $join->{table_name} other
                        ON (
                            self.$join->{join_column} = other.$join->{id_column}
                        )
                ORDER BY self.id;
            ];
            #die $sql;
        }
        elsif (defined $options->{name_column2}) {
            $sql = qq[
                SELECT  $options->{id_column}       AS id_col,
                        $options->{name_column}     AS name_col,
                        $options->{name_column2}    AS name_col2
                  FROM  $options->{table_name}
                 ORDER  BY $options->{id_column} ASC
            ];
        }
        else {
            $sql = qq[
                SELECT  $options->{id_column}       AS id_col,
                        $options->{name_column}     AS name_col
                  FROM  $options->{table_name}
                 ORDER  BY $options->{id_column} ASC
            ];
        }

        # prepare and execute
        $sth = $dbh->prepare( $sql ) or die $dbh->errstr();
        $sth->execute() or die "$sql - ". $dbh->errstr();

        # fetch values
        while ($res = $sth->fetchrow_hashref()) {
            print
                q{Readonly our $}
                . named_constant($options, $res)
                . qq{ => $res->{id_col};\n}
            if (0);
            push @constant_list,
                {
                    constant_name   => named_constant($options, $res),
                    constant_value  => $res->{id_col},
                }
            ;
        }
        $sth->finish;

        return \@constant_list;
    }

    sub named_constant {
        my ($options, $table_row) = @_;
        my $constant_name;

        # the label is $options->{name_column}
        if (not defined $options->{name_column}) {
            warn "constant_name is not defined";
            return;
        }

        $constant_name =
            ($options->{fake_table_name} || $options->{table_name} || '')
            . '__'
            . $table_row->{name_col}
        ;

        # if we've been given a second column to use for the constant name, glue it
        # on the end
        if (defined $table_row->{name_col2}) {
            $constant_name .=
                q{__}
                . $table_row->{name_col2}
            ;
        }

        # remove evil!
        if ($options->{no_dash}) {
          $constant_name =~ s{-}{_}g;
        }
        else {
          $constant_name =~ s{-}{_DASH_}g;
        }
        $constant_name =~ s{,}{_COMMA_}g;
        $constant_name =~ s{@}{_AT_}g;
        $constant_name =~ s{&}{_AMP_}g;
        $constant_name =~ s{/}{_FSLASH_}g;
        $constant_name =~ s{\'}{_APOS_}g;
        $constant_name =~ s{%}{_PC_}g;
        $constant_name =~ s{<}{_LT_}g;
        $constant_name =~ s{>}{_GT_}g;
        $constant_name =~ s{\(}{}g;
        $constant_name =~ s{\)}{}g;


        # replace spaces with underscores
        $constant_name =~ s{\s+}{_}g;

        # replace periods with underscored (this crept in when we started using
        # schemas
        $constant_name =~ s{\.}{_}g;

        # uppercase the string
        $constant_name = uc( $constant_name );

        return $constant_name;
    }

1; # be true

=pod

=head1 NAME

build_constants.pl - script to create XTracker::Constants::FromDB

=head1 USAGE

  # dump the generated config to STDOUT
  ./build_constants.pl

  # dump the output to the relevant module
  ./build_constants.pl > /var/data/xtracker/perl/XTracker/Constants/FromDB.pm # This is POD text

=head1 CONFIGURATION

The database used by the script is specified in the global xtracker
configuration file C</etc/xtracker/xtracker.conf>.

=head1 AUTHOR

Chisel Wright C< <<chisel.wright@net-a-porter.com>> >

=cut



__DATA__
package XTracker::Constants::FromDB;
use strict;
use warnings;

#########################################
## AUTOGENERATED APPLICATION CONSTANTS ##
##       DO NOT EDIT THIS FILE         ##
##   (See XTracker::BuildConstants)    ##
#########################################

use Const::Fast;
use base 'Exporter';

##
## CONSTANT DEFINITIONS
##

[%- FOREACH cg IN constant_group %]
# table: [% cg.name %]
[%- FOREACH constant IN cg.data %]
const our $[%constant.constant_name%] => [%constant.constant_value%];
[%- END %]
[%- IF cg.build_value_list;
    values = [];
    FOR constant IN cg.data; values.push(constant.constant_value); END; %]
const our @[%cg.name.upper()%]_VALUES => (qw/
    [% values.join(' ') %]
/);
[%- END %]
[% END %]

##
## EXPORTER GROUPS
##

[%- USE String -%]
[%- export_list = [] -%]

[%- FOREACH cg IN constant_group -%]
[%- tmp_string = cg.name _ '_LIST' -%]
[%- list_name = String.new(tmp_string).upper() %]
[%- export_list.push( { group => cg.name, list_name => list_name } ) -%]
# table: [% cg.name %]
our @[% list_name %] = qw(
[%- FOREACH constant IN cg.data %]
    $[%constant.constant_name%]
[%- END %]
[%- IF cg.build_value_list %]
    @[%cg.name.upper()%]_VALUES
[%- END %]
);
[% END %]

##
## @EXPORT_OK
##
our @EXPORT_OK = (
[%- FOREACH item IN export_list %]
    @[%item.list_name%],
[%- END %]
);

##
## %EXPORT_TAGS
##
our %EXPORT_TAGS = (
[%- FOREACH item IN export_list %]
    '[% item.group %]' => [ @[% item.list_name %] ],
[%- END %]
);

1;

# This file is generated by XTracker::BuildConstants (lib/XTracker/BuildConstants.pm)

use utf8;
package XTracker::Schema::Result::Public::Operator;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.operator");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "operator_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "password",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "auto_login",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "disabled",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "department_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "email_address",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "phone_ddi",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "use_ldap",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
  "last_login",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "use_acl_for_main_nav",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("operator_username_uniq", ["username"]);
__PACKAGE__->has_many(
  "address_change_logs",
  "XTracker::Schema::Result::Public::AddressChangeLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "allocation_item_logs",
  "XTracker::Schema::Result::Public::AllocationItemLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "bulk_reimbursements",
  "XTracker::Schema::Result::Public::BulkReimbursement",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "channel_transfer_picks",
  "XTracker::Schema::Result::Public::ChannelTransferPick",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "channel_transfer_putaways",
  "XTracker::Schema::Result::Public::ChannelTransferPutaway",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "correspondence_templates_logs",
  "XTracker::Schema::Result::Public::CorrespondenceTemplatesLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_actions",
  "XTracker::Schema::Result::Public::CustomerAction",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_credit_logs",
  "XTracker::Schema::Result::Public::CustomerCreditLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_notes",
  "XTracker::Schema::Result::Public::CustomerNote",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "dbadmin_log_back_fill_job_runs",
  "XTracker::Schema::Result::DBAdmin::LogBackFillJobRun",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "dbadmin_log_back_fill_job_statuses",
  "XTracker::Schema::Result::DBAdmin::LogBackFillJobStatus",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "delivery_date_restriction_logs",
  "XTracker::Schema::Result::Shipping::DeliveryDateRestrictionLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "delivery_notes_created",
  "XTracker::Schema::Result::Public::DeliveryNote",
  { "foreign.created_by" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "delivery_notes_modified",
  "XTracker::Schema::Result::Public::DeliveryNote",
  { "foreign.modified_by" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "department",
  "XTracker::Schema::Result::Public::Department",
  { id => "department_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "designer_log_attribute_values",
  "XTracker::Schema::Result::Designer::LogAttributeValue",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_archived_conditions_created",
  "XTracker::Schema::Result::Fraud::ArchivedCondition",
  { "foreign.created_by_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_archived_conditions_expired",
  "XTracker::Schema::Result::Fraud::ArchivedCondition",
  { "foreign.expired_by_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_archived_lists_created",
  "XTracker::Schema::Result::Fraud::ArchivedList",
  { "foreign.created_by_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_archived_lists_expired",
  "XTracker::Schema::Result::Fraud::ArchivedList",
  { "foreign.expired_by_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_archived_rules_created",
  "XTracker::Schema::Result::Fraud::ArchivedRule",
  { "foreign.created_by_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_archived_rules_expired",
  "XTracker::Schema::Result::Fraud::ArchivedRule",
  { "foreign.expired_by_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "fraud_change_logs",
  "XTracker::Schema::Result::Fraud::ChangeLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "ip_address_lists",
  "XTracker::Schema::Result::Fraud::IpAddressList",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_channel_transfers",
  "XTracker::Schema::Result::Public::LogChannelTransfer",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_deliveries",
  "XTracker::Schema::Result::Public::LogDelivery",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_designer_descriptions",
  "XTracker::Schema::Result::Public::LogDesignerDescription",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_locations",
  "XTracker::Schema::Result::Public::LogLocation",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_navigation_trees",
  "XTracker::Schema::Result::Product::LogNavigationTree",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_payment_fulfilled_changes",
  "XTracker::Schema::Result::Orders::LogPaymentFulfilledChange",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_payment_preauth_cancellations",
  "XTracker::Schema::Result::Orders::LogPaymentPreauthCancellation",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_pws_stocks",
  "XTracker::Schema::Result::Public::LogPwsStock",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_replaced_payment_fulfilled_changes",
  "XTracker::Schema::Result::Orders::LogReplacedPaymentFulfilledChange",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_replaced_payment_preauth_cancellations",
  "XTracker::Schema::Result::Orders::LogReplacedPaymentPreauthCancellation",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_rtv_stocks",
  "XTracker::Schema::Result::Public::LogRtvStock",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_rule_engine_switch_positions",
  "XTracker::Schema::Result::Fraud::LogRuleEngineSwitchPosition",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_shipment_rtcb_states",
  "XTracker::Schema::Result::Public::LogShipmentRtcbState",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_shipment_signature_requireds",
  "XTracker::Schema::Result::Public::LogShipmentSignatureRequired",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_stocks",
  "XTracker::Schema::Result::Public::LogStock",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_website_states",
  "XTracker::Schema::Result::Designer::LogWebsiteState",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_welcome_pack_changes",
  "XTracker::Schema::Result::Public::LogWelcomePackChange",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "manifest_status_logs",
  "XTracker::Schema::Result::Public::ManifestStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "marketing_customer_segment_logs",
  "XTracker::Schema::Result::Public::MarketingCustomerSegmentLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "marketing_customer_segments",
  "XTracker::Schema::Result::Public::MarketingCustomerSegment",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "marketing_promotion_logs",
  "XTracker::Schema::Result::Public::MarketingPromotionLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "marketing_promotions",
  "XTracker::Schema::Result::Public::MarketingPromotion",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "navigation_tree_locks",
  "XTracker::Schema::Result::Product::NavigationTreeLock",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "operator_authorisations",
  "XTracker::Schema::Result::Public::OperatorAuthorisation",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "operator_preference",
  "XTracker::Schema::Result::Public::OperatorPreference",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_address_logs",
  "XTracker::Schema::Result::Public::OrderAddressLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_email_logs",
  "XTracker::Schema::Result::Public::OrderEmailLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_notes",
  "XTracker::Schema::Result::Public::OrderNote",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "order_status_logs",
  "XTracker::Schema::Result::Public::OrderStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orphan_items",
  "XTracker::Schema::Result::Public::OrphanItem",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_applied_discounts",
  "XTracker::Schema::Result::Public::PreOrder",
  { "foreign.applied_discount_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_email_logs",
  "XTracker::Schema::Result::Public::PreOrderEmailLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_item_status_logs",
  "XTracker::Schema::Result::Public::PreOrderItemStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_notes",
  "XTracker::Schema::Result::Public::PreOrderNote",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_operator_log_from_operator",
  "XTracker::Schema::Result::Public::PreOrderOperatorLog",
  { "foreign.from_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_operator_log_operator",
  "XTracker::Schema::Result::Public::PreOrderOperatorLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_operator_log_to_operator",
  "XTracker::Schema::Result::Public::PreOrderOperatorLog",
  { "foreign.to_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_refund_failed_logs",
  "XTracker::Schema::Result::Public::PreOrderRefundFailedLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_refund_status_logs",
  "XTracker::Schema::Result::Public::PreOrderRefundStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_order_status_logs",
  "XTracker::Schema::Result::Public::PreOrderStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_orders",
  "XTracker::Schema::Result::Public::PreOrder",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "price_defaults",
  "XTracker::Schema::Result::Public::PriceDefault",
  { "foreign.complete_by_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "product_log_attribute_values",
  "XTracker::Schema::Result::Product::LogAttributeValue",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "promotion_customer_customergroups_created",
  "XTracker::Schema::Result::Promotion::CustomerCustomerGroup",
  { "foreign.created_by" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "promotion_customer_customergroups_modified",
  "XTracker::Schema::Result::Promotion::CustomerCustomerGroup",
  { "foreign.modified_by" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "promotion_details_created",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.created_by" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "promotion_details_last_modified",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.last_modified_by" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "published_logs",
  "XTracker::Schema::Result::WebContent::PublishedLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "purchase_orders",
  "XTracker::Schema::Result::Public::PurchaseOrder",
  { "foreign.confirmed_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "putaway_prep_containers",
  "XTracker::Schema::Result::Public::PutawayPrepContainer",
  { "foreign.user_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "recent_audits",
  "XTracker::Schema::Result::Audit::Recent",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "renumeration_change_logs",
  "XTracker::Schema::Result::Public::RenumerationChangeLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "renumeration_status_logs",
  "XTracker::Schema::Result::Public::RenumerationStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_auto_change_logs",
  "XTracker::Schema::Result::Public::ReservationAutoChangeLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_logs",
  "XTracker::Schema::Result::Public::ReservationLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_operator_log_from_operator",
  "XTracker::Schema::Result::Public::ReservationOperatorLog",
  { "foreign.from_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_operator_log_operator",
  "XTracker::Schema::Result::Public::ReservationOperatorLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservation_operator_log_to_operator",
  "XTracker::Schema::Result::Public::ReservationOperatorLog",
  { "foreign.to_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "reservations",
  "XTracker::Schema::Result::Public::Reservation",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_arrivals",
  "XTracker::Schema::Result::Public::ReturnArrival",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_delivery_created_bies",
  "XTracker::Schema::Result::Public::ReturnDelivery",
  { "foreign.created_by" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_delivery_operator_ids",
  "XTracker::Schema::Result::Public::ReturnDelivery",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_email_logs",
  "XTracker::Schema::Result::Public::ReturnEmailLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_item_status_logs",
  "XTracker::Schema::Result::Public::ReturnItemStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_notes",
  "XTracker::Schema::Result::Public::ReturnNote",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_status_logs",
  "XTracker::Schema::Result::Public::ReturnStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rma_request_detail_status_logs",
  "XTracker::Schema::Result::Public::RmaRequestDetailStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rma_requests",
  "XTracker::Schema::Result::Public::RmaRequest",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "routing_export_status_logs",
  "XTracker::Schema::Result::Public::RoutingExportStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_inspection_pick_requests",
  "XTracker::Schema::Result::Public::RTVInspectionPickRequest",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "rtv_shipment_status_logs",
  "XTracker::Schema::Result::Public::RTVShipmentStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_address_logs",
  "XTracker::Schema::Result::Public::ShipmentAddressLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_box_logs",
  "XTracker::Schema::Result::Public::ShipmentBoxLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_email_logs",
  "XTracker::Schema::Result::Public::ShipmentEmailLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_extra_items",
  "XTracker::Schema::Result::Public::ShipmentExtraItem",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_hold_logs",
  "XTracker::Schema::Result::Public::ShipmentHoldLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_holds",
  "XTracker::Schema::Result::Public::ShipmentHold",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_item_container_logs",
  "XTracker::Schema::Result::Public::ShipmentItemContainerLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_item_status_logs",
  "XTracker::Schema::Result::Public::ShipmentItemStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_message_logs",
  "XTracker::Schema::Result::Public::ShipmentMessageLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_notes",
  "XTracker::Schema::Result::Public::ShipmentNote",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_status_logs",
  "XTracker::Schema::Result::Public::ShipmentStatusLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_attribute_packing_notes",
  "XTracker::Schema::Result::Public::ShippingAttribute",
  { "foreign.packing_note_operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_attributes",
  "XTracker::Schema::Result::Public::ShippingAttribute",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "sticky_page",
  "XTracker::Schema::Result::Operator::StickyPage",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "transfers",
  "XTracker::Schema::Result::Upload::Transfer",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "variant_measurements_logs",
  "XTracker::Schema::Result::Public::VariantMeasurementsLog",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "voucher_products",
  "XTracker::Schema::Result::Voucher::Product",
  { "foreign.operator_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "voucher_purchase_orders",
  "XTracker::Schema::Result::Voucher::PurchaseOrder",
  { "foreign.created_by" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "web_content_instances_created",
  "XTracker::Schema::Result::WebContent::Instance",
  { "foreign.created_by" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "web_content_instances_last_updated",
  "XTracker::Schema::Result::WebContent::Instance",
  { "foreign.last_updated_by" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9t6XFvpOzlnebF5M367KCQ

__PACKAGE__->add_unique_constraint(username => ["username"]);

# Duplicate of operator_authorisations
__PACKAGE__->has_many(
    'permissions' => 'Public::OperatorAuthorisation',
    { 'foreign.operator_id' => 'self.id' },
);
__PACKAGE__->has_many(
    'operator_role' => 'Public::OperatorRole',
    { 'foreign.operator_id' => 'self.id' },
);

__PACKAGE__->has_many(
    'sent_messages' => 'Operator::Message',
    { 'foreign.sender_id' => 'self.id' },
);

__PACKAGE__->has_many(
    'received_messages' => 'Operator::Message',
    { 'foreign.recipient_id' => 'self.id' },
);

use XTracker::Printers;
use XTracker::Config::Local         qw( sys_config_var order_search_by_designer_result_file_path );
use XTracker::Constants::FromDB     qw( :authorisation_level );

use Carp;

use IO::File;
use Text::CSV;
use File::Copy;


sub initials {
    my $self = shift;
    my ($initials);

    $initials = join q{}, ($self->name() =~ /\b\w/g);

    return $initials;
}

sub customer_ref {
    my $self    = shift;
    my $customer_ref;

    $customer_ref   = join q{.},$self->name(),$self->id();

    return $customer_ref;
}

sub send_message {
    my ($record, $attr) = @_;
    my $schema = $record->result_source()->schema();

    $schema->resultset('Operator::Message')->create(
        {
            subject         => $attr->{subject},
            body            => $attr->{message},
            sender_id       => $attr->{sender},
            recipient_id    => $record->id,
        }
    );
}

sub check_if_has_role {
    # Syntax: if ( $operator->check_if_has_role('Web contant administrator') )
    my ($self,$role_to_search_for) = @_;
    my $schema = $self->result_source()->schema();

    my $role = $schema->resultset('Public::Role')->search({
        role_name => $role_to_search_for,
    });

    my $role_id;
    $role_id = $role->first->id if defined $role;

    if($role_id){
        my $role_link = $schema->resultset('Public::OperatorRole')->search({
            operator_id => $self->id,
            role_id     => $role_id,
        });
        return 1 if $role_link->first;
    }
    return 0;
}

sub _set_role {
    # Used for testing purposes and for future implementation
    my ($self,$role_to_add) = @_;

    my $schema = $self->result_source()->schema();

    my $role = $schema->resultset('Public::Role')->search({
        role_name => $role_to_add,
    });

    my $role_id;
    $role_id = $role->first->id if defined $role;

    if($role_id){
        my $role_links = $schema->resultset('Public::OperatorRole');

        my $role_link_existence = $role_links->search({
            operator_id => $self->id,
            role_id     => $role_id,
        });

        unless( $role_link_existence->first ){
            $role_links->create({
                operator_id => $self->id,
                role_id     => $role_id,
            });
        }
    }
}

sub _remove_role {
    # Used for testing purposes and for future implementation
    my ($self,$role_to_add) = @_;

    my $schema = $self->result_source()->schema();

    my $role = $schema->resultset('Public::Role')->search({
        role_name => $role_to_add,
    });

    my $role_id;
    $role_id = $role->first->id if defined $role;

    if($role_id){
        my $role_links = $schema->resultset('Public::OperatorRole');

        my $role_link_existence = $role_links->search({
            operator_id => $self->id,
            role_id     => $role_id,
        });

        if( $role_link_existence->first ){
            $role_links->search({
                operator_id => $self->id,
                role_id     => $role_id,
            })->delete();
        }
    }
}

sub _auth_level_for_sub_section {
    my ( $self, $section_name, $sub_section_name ) = @_;

    my $sub_section = $self->result_source->schema->resultset('Public::AuthorisationSubSection')->find(
        {
            'me.sub_section'    => $sub_section_name,
            'section.section'   => $section_name,
        },
        {
            'join'              => 'section'
        },
    );

    if ( $sub_section ) {

        my $permission = $self->permissions->find( { authorisation_sub_section_id => $sub_section->id } );

        if ( defined $permission ) {

            return $permission->authorisation_level_id;

        }

    } else {

        return 0;

    }

}

sub is_manager {
    my ( $self, $section_name, $sub_section_name ) = @_;

    return 1 if $self->_auth_level_for_sub_section( $section_name, $sub_section_name ) == $AUTHORISATION_LEVEL__MANAGER;
    return 0;

}

sub is_operator {
    my ( $self, $section_name, $sub_section_name ) = @_;

    return 1 if $self->is_manager( $section_name, $sub_section_name );
    return 1 if $self->_auth_level_for_sub_section( $section_name, $sub_section_name ) == $AUTHORISATION_LEVEL__OPERATOR;
    return 0;

}

sub is_read_only {
    my ( $self, $section_name, $sub_section_name ) = @_;

    return 1 if $self->is_operator( $section_name, $sub_section_name );
    # will also return 1 if 'is_manager' (called by 'is_operator').
    return 1 if $self->_auth_level_for_sub_section( $section_name, $sub_section_name ) == $AUTHORISATION_LEVEL__READ_ONLY;
    return 0;

}

=head2 authorisation_as_hash() : \%authorisation

Returns a with a hash representing authorisations for this user. The hash has
the following structure:

    { $section_name => { $sub_section => sub_section_id } }

=cut

sub authorisation_as_hash {
    my $self = shift;

    my $operator_authorisation_with_prefetch
        = $self->operator_authorisations->search(undef, {
            prefetch => { auth_sub_section => 'section' },
        });

    my %auth;
    for my $row ( $operator_authorisation_with_prefetch->all ) {
        $auth{ $_->section->section }{ $_->sub_section } = $_->id
            for $row->auth_sub_section;
    }
    return \%auth;
}

=head2 update_or_create_preferences(\%preferences) : $operator_authorisation_row

Update or create the operator preference row referencing this operator. For
backwards-compatibility reasons this method will not error if passed
non-existent columns, and will ignore any values for C<operator_id> if passed.

=cut

sub update_or_create_preferences {
    my ( $self, $params ) = @_;

    # Populate the operator_preference table with the following (refactored - I
    # didn't make them up) rules:
    # * Parameters that don't have a column with the same name will be ignored.
    # * If the parameter has a false value it will be set to null
    my $operator_preference_rs
        = $self->result_source->schema->resultset('Public::OperatorPreference');
    my %data_cols = map {
        $_ => $params->{$_} || undef
    } grep {
        $_ ne 'operator_id' && exists $params->{$_}
    } $operator_preference_rs->result_source->columns;

    return $operator_preference_rs->update_or_create(
        { %data_cols, operator_id => $self->id }, { key => 'primary' }
    );
}

=head2 has_location_for_section($section) : Bool

Returns a true value if the operator's configured printer station belongs to
the given C<$section>.

=cut

sub has_location_for_section {
    my ( $self, $section ) = @_;
    my $location = $self->printer_location or return undef;
    return $location->section->name eq $section;
}

=head2 printer_preference() : $location_name

=cut

sub printer_location {
    my $self = shift;
    my $preference = $self->operator_preference or return undef;
    return XTracker::Printers->new->location(
        $preference->printer_station_name
    );
}

=head2 create_orders_search_by_designer_file_name

    $string = $self->create_orders_search_by_designer_file_name( {
        designer    => $designer_rec,
        state       => 'pending',
        # required if state is 'completed'
        number_of_records => 563,
        # optional
        channel    => $channel_rec,
    } );

Create a file-name that will be used with the 'Search Orders by Designer' functionality.

'state' can be one of the following:

    * 'pending'   - default, will create a file with 'PENDING' in the file-name to
                    simulate when a request to do a Search on a Designer is pending
    * 'searching' - will create a file with 'SEARCHING' in the file-name to indicate
                    when a search for a Designer is actually taking place
    * 'completed' - will create a file with 'COMPLETED' in the file-name to indicate
                    when a search has completed

'number_of_records' will be used for 'completed' file-names to indicate the number of records found.

=cut

sub create_orders_search_by_designer_file_name {
    my ( $self, $args ) = @_;

    foreach my $arg ( qw( designer state ) ) {
        croak "No '${arg}' passed in to 'create_orders_search_by_designer_file_name'"
                        if ( !$args->{ $arg } );
    }

    my %states = (
        pending   => sub { return 'PENDING'; },
        searching => sub { return 'SEARCHING'; },
        completed => sub {
                my $args = shift;
                croak "No 'number_of_records' passed in when state is 'completed' to 'create_orders_search_by_designer_file_name'"
                                    if ( !defined $args->{number_of_records} );
                return 'COMPLETED_' . $args->{number_of_records};
            },
    );

    my $designer = $args->{designer};
    my $channel  = $args->{channel};
    my $state    = lc( $args->{state} );

    croak "Unrecognised State: '${state}' passed in to 'create_orders_search_by_designer_file_name'"
                    if ( !exists $states{ $state } );

    # get the current time in the DB
    my $now     = $self->result_source->schema->db_now();
    my $now_str = $now->ymd('') . $now->hms('');

    my $state_str = $states{ $state }->( $args );

    # if no Channel then set Channel Id as ZERO
    my $channel_id = ( $channel ? $channel->id : 0 );

    # return the file-name
    return $self->id . '_' . $designer->id . '_' . $channel_id . '_' . $now_str . '_' . $state_str . '.txt';
}

=head2 create_completed_orders_search_by_designer_results_file

    $hash_ref = $self->create_completed_orders_search_by_designer_results_file( $designer_rec );
                or
    $hash_ref = $self->create_completed_orders_search_by_designer_results_file( $designer_rec, $channel_rec );

This will Search for Orders by Designer and optionally Sales Channel as well and then create a
Completed Search Results file for the Operator writing the Results of the Search to it.

It won't find all Orders but only those that have been created after the search window period
specified in the System Config in the 'order_search' group.

Instead of Searching for the Orders using one Query it will break up the search by finding all of the
Variants for the Designer and then for each Variant find all the Shipments that have at least one item
for the Variant. It will be the Shipment's date that will be used to see if the Shipment is in the
search window. If a Sales Channel has been passed in then when searching for Shipments it will join
to the 'orders' table and check the 'channel_id' field.

This will return a Hash Ref. with some details of the search:

    {
        file_name         => 'COMPLETED_FILE_NAME.txt',
        number_of_records => 1234,
    }

=cut

sub create_completed_orders_search_by_designer_results_file {
    my ( $self, $designer, $channel ) = @_;

    my $schema      = $self->result_source->schema;
    my $shipment_rs = $schema->resultset('Public::Shipment');

    # create a 'Searching' file which will be populated with the Results
    my $file_name = $self->create_orders_search_by_designer_file_name( {
        designer => $designer,
        state    => 'searching',
        channel  => $channel,
    } );
    # get the path to create the results file in
    my $results_path   = order_search_by_designer_result_file_path();
    my $full_file_name = "${results_path}/${file_name}";

    # create the 'Searching' file before doing
    # the Search, so it acts as a place-holder
    my $fh = IO::File->new( ">${full_file_name}" )
                || croak "Couldn't create Searching file '${full_file_name}': " . $! . "\n";
    $fh->close();

    # get from config how far back to look for Shipments
    my $shipment_search_interval = sys_config_var( $schema, 'order_search', 'by_designer_search_window' );

    # get the minimum Shipment Id that all Shipments should be greater than
    my $minimum_shipment_id = $shipment_rs->get_historic_min_shipment_id( $shipment_search_interval );

    # loop through all the Variants for the Designer
    # and get all the Shipments for each Variant
    my $variant_rs = $schema->resultset('Public::Variant')
                                ->get_variant_ids_for_designer( $designer );

    # use this to store the Shipment Ids which will also mean they are de-duped
    my %shipment_ids;
    my $number_of_records = 0;
    while ( my $variant_id = $variant_rs->next ) {
        my $shipment_id_rs = $shipment_rs->get_shipment_ids_for_variant_id( $variant_id, {
            min_shipment_id => $minimum_shipment_id,
            channel         => $channel,
        } );

        SHIPMENT:
        while ( my $shipment_id = $shipment_id_rs->next ) {
            next SHIPMENT       if ( exists( $shipment_ids{ $shipment_id } ) );

            # store the Id
            $shipment_ids{ $shipment_id } = 1;

            $number_of_records++;
        }
    }

    # output all of the Shipment Ids sorting in reverse Order
    # as the higher the Id the most recent Shipment, so in other
    # words output the Shipment Ids in Descending order

    my $csv = Text::CSV->new( {
        binary => 1,
        eol    => "\n",
        always_quote => 1,
    } );

    # this will output to the 'Searching' file
    my $csv_fh = IO::File->new( $full_file_name, ">:encoding(utf8)" )
                    || croak "Couldn't open file for writing - '${full_file_name}': " . $!;

    # write the header row
    $csv->print( $csv_fh, [ 'shipment_id' ] );

    foreach my $shipment_id ( sort { $b <=> $a } keys( %shipment_ids ) ) {
        $csv->print( $csv_fh, [ $shipment_id ] );
    }

    $csv_fh->close();

    # now rename the file to be 'Completed'
    my $completed_file_name = $self->create_orders_search_by_designer_file_name( {
        designer => $designer,
        state    => 'completed',
        channel  => $channel,
        number_of_records => $number_of_records,
    } );
    my $completed_full_file_name = "${results_path}/${completed_file_name}";

    move( $full_file_name, $completed_full_file_name )
                || croak "Couldn't move file to be Completed - '${full_file_name}' to '${completed_full_file_name}': " . $!;

    return {
        file_name         => $completed_file_name,
        number_of_records => $number_of_records,
    };
}


1; # be true;

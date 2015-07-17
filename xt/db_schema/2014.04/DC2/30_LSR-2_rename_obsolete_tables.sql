-- LSR-2: Remove Obsolete Tables.

BEGIN WORK;

-- Tables not referenced in the codebase.
ALTER TABLE public.attribute_aligns RENAME TO public_attribute_aligns;
ALTER TABLE public.public_attribute_aligns SET SCHEMA obsolete;

ALTER TABLE public.attribute_aligns_bu RENAME TO public_attribute_aligns_bu;
ALTER TABLE public.public_attribute_aligns_bu SET SCHEMA obsolete;

ALTER TABLE public.attribute_aligns_ids RENAME TO public_attribute_aligns_ids;
ALTER TABLE public.public_attribute_aligns_ids SET SCHEMA obsolete;

ALTER TABLE public.ben_tmp RENAME TO public_ben_tmp;
ALTER TABLE public.public_ben_tmp SET SCHEMA obsolete;

ALTER TABLE public.country_category_mapping RENAME TO public_country_category_mapping;
ALTER TABLE public.public_country_category_mapping SET SCHEMA obsolete;

ALTER TABLE public.customer_issue_type_class RENAME TO public_customer_issue_type_class;
ALTER TABLE public.public_customer_issue_type_class SET SCHEMA obsolete;

ALTER TABLE public.dhl_inbound_tariff RENAME TO public_dhl_inbound_tariff;
ALTER TABLE public.public_dhl_inbound_tariff SET SCHEMA obsolete;

ALTER TABLE public.legacy_country_tax RENAME TO public_legacy_country_tax;
ALTER TABLE public.public_legacy_country_tax SET SCHEMA obsolete;

ALTER TABLE public.legacy_designer_size RENAME TO public_legacy_designer_size;
ALTER TABLE public.public_legacy_designer_size SET SCHEMA obsolete;

ALTER TABLE public.legacy_link_tax_rates RENAME TO public_legacy_link_tax_rates;
ALTER TABLE public.public_legacy_link_tax_rates SET SCHEMA obsolete;

ALTER TABLE public.locations_backup_am_20060526 RENAME TO public_locations_backup_am_20060526;
ALTER TABLE public.public_locations_backup_am_20060526 SET SCHEMA obsolete;

ALTER TABLE public.london_shipping_zone RENAME TO public_london_shipping_zone;
ALTER TABLE public.public_london_shipping_zone SET SCHEMA obsolete;

ALTER TABLE public.message_actionlog RENAME TO public_message_actionlog;
ALTER TABLE public.public_message_actionlog SET SCHEMA obsolete;

ALTER TABLE public.message_actiontype RENAME TO public_message_actiontype;
ALTER TABLE public.public_message_actiontype SET SCHEMA obsolete;

ALTER TABLE public.message_working RENAME TO public_message_working;
ALTER TABLE public.public_message_working SET SCHEMA obsolete;

ALTER TABLE public.message_category RENAME TO public_message_category;
ALTER TABLE public.public_message_category SET SCHEMA obsolete;

ALTER TABLE public.message_customer_order_case_link RENAME TO public_message_customer_order_case_link;
ALTER TABLE public.public_message_customer_order_case_link SET SCHEMA obsolete;

ALTER TABLE public.message_customer_order_link RENAME TO public_message_customer_order_link;
ALTER TABLE public.public_message_customer_order_link SET SCHEMA obsolete;

ALTER TABLE public.message_store RENAME TO public_message_store;
ALTER TABLE public.public_message_store SET SCHEMA obsolete;

ALTER TABLE public.notes_product_temp RENAME TO public_notes_product_temp;
ALTER TABLE public.public_notes_product_temp SET SCHEMA obsolete;

ALTER TABLE public.old_putaway RENAME TO public_old_putaway;
ALTER TABLE public.public_old_putaway SET SCHEMA obsolete;

ALTER TABLE public.size_old RENAME TO public_size_old;
ALTER TABLE public.public_size_old SET SCHEMA obsolete;

ALTER TABLE public.tmp_ben RENAME TO public_tmp_ben;
ALTER TABLE public.public_tmp_ben SET SCHEMA obsolete;

ALTER TABLE public.tmp_cust_cat RENAME TO public_tmp_cust_cat;
ALTER TABLE public.public_tmp_cust_cat SET SCHEMA obsolete;

ALTER TABLE public.tmp_eip RENAME TO public_tmp_eip;
ALTER TABLE public.public_tmp_eip SET SCHEMA obsolete;

ALTER TABLE public.tmp_pid_lookup RENAME TO public_tmp_pid_lookup;
ALTER TABLE public.public_tmp_pid_lookup SET SCHEMA obsolete;

ALTER TABLE public.tmp_prod RENAME TO public_tmp_prod;
ALTER TABLE public.public_tmp_prod SET SCHEMA obsolete;

ALTER TABLE public.tmp_promo RENAME TO public_tmp_promo;
ALTER TABLE public.public_tmp_promo SET SCHEMA obsolete;

ALTER TABLE public.variant_measurement_backup RENAME TO public_variant_measurement_backup;
ALTER TABLE public.public_variant_measurement_backup SET SCHEMA obsolete;

ALTER TABLE shipping.zone_location RENAME TO shipping_zone_location;
ALTER TABLE shipping.shipping_zone_location SET SCHEMA obsolete;

-- ALTER TABLE public.address_change_log RENAME TO public_address_change_log;
-- ALTER TABLE public.public_address_change_log SET SCHEMA obsolete;

ALTER TABLE public.message_type RENAME TO public_message_type;
ALTER TABLE public.public_message_type SET SCHEMA obsolete;

ALTER TABLE public.old_quantity RENAME TO public_old_quantity;
ALTER TABLE public.public_old_quantity SET SCHEMA obsolete;

ALTER TABLE public.markdown RENAME TO public_markdown;
ALTER TABLE public.public_markdown SET SCHEMA obsolete;

ALTER TABLE public.product_classification_structure RENAME TO public_product_classification_structure;
ALTER TABLE public.public_product_classification_structure SET SCHEMA obsolete;

ALTER TABLE orders.temp_payment RENAME TO orders_temp_payment;
ALTER TABLE orders.orders_temp_payment SET SCHEMA obsolete;

ALTER TABLE public.legacy_shipprodtype RENAME TO public_legacy_shipprodtype;
ALTER TABLE public.public_legacy_shipprodtype SET SCHEMA obsolete;

ALTER TABLE public.markdown_type RENAME TO public_markdown_type;
ALTER TABLE public.public_markdown_type SET SCHEMA obsolete;

ALTER TABLE public.email_template RENAME TO public_email_template;
ALTER TABLE public.public_email_template SET SCHEMA obsolete;

ALTER TABLE public.notes_product_lastupdate RENAME TO public_notes_product_lastupdate;
ALTER TABLE public.public_notes_product_lastupdate SET SCHEMA obsolete;

ALTER TABLE product.stock_summary_foreign RENAME TO product_stock_summary_foreign;
ALTER TABLE product.product_stock_summary_foreign SET SCHEMA obsolete;

ALTER TABLE public.notes_product3 RENAME TO public_notes_product3;
ALTER TABLE public.public_notes_product3 SET SCHEMA obsolete;

ALTER TABLE public.pricing RENAME TO public_pricing;
ALTER TABLE public.public_pricing SET SCHEMA obsolete;

COMMIT WORK;
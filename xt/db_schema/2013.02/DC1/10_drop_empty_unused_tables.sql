BEGIN;

-- Attempt two with trying to get this patch applied to clean up some unused
-- tables that were highlighted many moons ago - Jason Tang

-- SQL to remove unused tables with no rows in them
-- 25 Feb 2008
-- Jason Tang jason.tang@net-a-porter.com

-- NO SPAM! select 'information_schema.sql_sizing_profiles';
--drop table information_schema.sql_sizing_profiles;
-- NO SPAM! select 'public.address';
drop table public.address;
-- NO SPAM! select 'public.address_change_log';
--drop table public.address_change_log;
-- NO SPAM! select 'public.address_type';
drop table public.address_type;
-- NO SPAM! select 'public.customer_altemailaddr';
drop table public.customer_altemailaddr;
-- NO SPAM! select 'public.customer_enquiry_case_issue_link';
drop table public.customer_enquiry_case_issue_link;
-- NO SPAM! select 'public.customer_enquiry_case_summary';

--alter table public.message_customer_order_case_link
--	drop constraint message_customer_order_reference_link_case_id_fkey;
alter table public.customer_order_enquiry_case_link
	drop constraint customer_order_enquiry_case_link_case_id_fkey;

drop table public.customer_enquiry_case_summary;
-- NO SPAM! select 'public.customer_enquiry_case_status';
drop table public.customer_enquiry_case_status;
-- NO SPAM! select 'public.customer_notes';
drop table public.customer_notes;
-- NO SPAM! select 'public.customer_notes_access';
drop table public.customer_notes_access;
-- NO SPAM! select 'public.customer_notes_type';
drop table public.customer_notes_type;
-- NO SPAM! select 'public.customer_order_enquiry_case_link';
drop table public.customer_order_enquiry_case_link;
-- NO SPAM! select 'public.customer_order_link';
drop table public.customer_order_link;
-- NO SPAM! select 'public.customer_order_reference';

--alter table message_customer_order_case_link
--	drop constraint message_customer_order_reference_link_coref_id_fkey;

drop table public.customer_order_reference;
-- NO SPAM! select 'public.email_log';
drop table public.email_log;
-- NO SPAM! select 'public.link_delivery_item__quantity';
--drop table public.link_delivery_item__quantity;
-- NO SPAM! select 'public.location_delivery';
drop table public.location_delivery;
-- NO SPAM! select 'public.notes_temp';
drop table public.notes_temp;
-- NO SPAM! select 'public.product_sales_data';
drop table public.product_sales_data;
-- NO SPAM! select 'public.qc_status';
drop table public.qc_status;
-- NO SPAM! select 'public.quantity_type';
drop table public.quantity_type;
-- NO SPAM! select 'public.rtv_shipment_packing_detail';
drop table public.rtv_shipment_packing_detail;
-- NO SPAM! select 'public.state_shipping_charge';
--drop table public.state_shipping_charge;
-- NO SPAM! select 'public.stock_movement';
drop table public.stock_movement;
-- NO SPAM! select 'public.upload_log';
drop table public.upload_log;
-- NO SPAM! select 'public.variant_action';
drop table public.variant_action;
-- NO SPAM! select 'public.variant_sales_data';
drop table public.variant_sales_data;

-- added by hand
-- NO SPAM! select 'public.printer';
drop table public.printer;
-- NO SPAM! select 'public.retailcalendar';
drop table public.retailcalendar;
-- NO SPAM! select 'public.rsd_docs';
drop table public.rsd_docs;
-- NO SPAM! select 'public.rsd_titles';
drop table public.rsd_titles;
-- NO SPAM! select 'public.rsd_headings';
drop table public.rsd_headings;

COMMIT;


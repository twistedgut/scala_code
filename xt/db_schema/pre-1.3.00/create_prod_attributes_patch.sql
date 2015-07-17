-- Purpose:


BEGIN;

-- adding new fields to product_attribute table
alter table product_attribute add column fit_notes varchar(255) null;
alter table product_attribute add column style_notes varchar(255) null;
alter table product_attribute add column editorial_approved boolean default false;
alter table product_attribute add column use_measurements boolean default true;

COMMIT;

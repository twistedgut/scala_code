-- Purpose:


BEGIN;

-- adding new fields to product_attribute table
alter table product_attribute add column editorial_notes text null;
alter table product_attribute add column outfit_links boolean default false;
alter table product_attribute add column fit_notes_required boolean default false;

COMMIT;

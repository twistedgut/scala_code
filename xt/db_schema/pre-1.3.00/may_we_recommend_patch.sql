-- Purpose:
--  

BEGIN;

-- Add marketing contact opt out field to customer table
alter table recommended_product add column sort_order integer null;
alter table recommended_product add column slot integer null;
alter table recommended_product add column approved boolean null default false;

COMMIT;
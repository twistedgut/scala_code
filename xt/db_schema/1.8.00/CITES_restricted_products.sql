-- New column for shipping attribute table, CITES restricted products
-- tables
BEGIN;
    
ALTER TABLE shipping_attribute ADD COLUMN cites_restricted boolean default false;

COMMIT;

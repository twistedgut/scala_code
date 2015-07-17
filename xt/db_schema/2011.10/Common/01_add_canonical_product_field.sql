-- Add canonical product column to product table

BEGIN;
    ALTER TABLE product
        ADD COLUMN canonical_product_id integer;
COMMIT;

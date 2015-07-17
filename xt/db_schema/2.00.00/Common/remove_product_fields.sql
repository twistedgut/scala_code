BEGIN;

DROP VIEW IF EXISTS product.vw_uploaded_products;

-- remove fields from product table
ALTER TABLE product DROP COLUMN live;
ALTER TABLE product DROP COLUMN staging;
ALTER TABLE product DROP COLUMN visible;
ALTER TABLE product DROP COLUMN disableupdate;

COMMIT;
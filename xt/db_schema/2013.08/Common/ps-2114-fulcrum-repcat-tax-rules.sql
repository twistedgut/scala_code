BEGIN;

ALTER TABLE product_type_tax_rate ADD COLUMN fulcrum_reporting_id integer;

COMMIT;

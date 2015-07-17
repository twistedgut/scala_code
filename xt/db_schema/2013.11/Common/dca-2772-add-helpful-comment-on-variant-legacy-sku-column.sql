BEGIN;

COMMENT ON COLUMN variant.legacy_sku IS 'Do not use this column, instead call the sku method in the Result class';

COMMIT;

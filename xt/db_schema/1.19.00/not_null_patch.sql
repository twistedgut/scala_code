-- These fields are unique but nullable...

BEGIN;

    ALTER TABLE classification ALTER COLUMN classification SET NOT NULL;
    ALTER TABLE designer ALTER COLUMN designer SET NOT NULL;
    ALTER TABLE location ALTER COLUMN location SET NOT NULL;
    ALTER TABLE old_location ALTER COLUMN location SET NOT NULL;
    ALTER TABLE outfit ALTER COLUMN name SET NOT NULL;
    ALTER TABLE product_type ALTER COLUMN product_type SET NOT NULL;
    ALTER TABLE stock_movement ALTER COLUMN product_id SET NOT NULL;
    ALTER TABLE sub_type ALTER COLUMN sub_type SET NOT NULL;

COMMIT;

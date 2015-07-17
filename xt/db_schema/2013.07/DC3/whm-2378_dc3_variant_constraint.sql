-- Add SKU unique constraint to variant on DC3

BEGIN;
    ALTER TABLE variant ADD UNIQUE ( product_id, size_id, type_id );
COMMIT;

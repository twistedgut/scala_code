-- Add foreign key constraint to type_id column in variant table

BEGIN;

ALTER TABLE variant ADD FOREIGN KEY (type_id) REFERENCES variant_type(id);

COMMIT;

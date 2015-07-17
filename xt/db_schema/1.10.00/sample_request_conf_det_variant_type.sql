
-- Alter column type to match that of referenced table

BEGIN;

ALTER TABLE sample_request_conf_det ALTER COLUMN variant_id TYPE integer USING CAST(variant_id AS integer);

COMMIT;

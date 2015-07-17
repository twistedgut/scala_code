-- Add is_hazmat flag to shipping attribute

BEGIN;
    ALTER TABLE shipping_attribute ADD is_hazmat BOOLEAN NOT NULL DEFAULT FALSE;
COMMIT;

-- Remove a duplicate fk

BEGIN;
    ALTER TABLE country DROP CONSTRAINT country_shipping_zone_id;
COMMIT;

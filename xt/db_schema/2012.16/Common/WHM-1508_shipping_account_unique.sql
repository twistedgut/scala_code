-- Add a unique constraint to the shipping account table

BEGIN;
    ALTER TABLE shipping_account ADD UNIQUE (name, carrier_id, channel_id);
COMMIT;

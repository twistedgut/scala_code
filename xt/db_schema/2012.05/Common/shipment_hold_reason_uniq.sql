-- Add a unique constraint to shipment_hold_reason(reason)

BEGIN;
    ALTER TABLE shipment_hold_reason ADD UNIQUE (reason);
COMMIT;

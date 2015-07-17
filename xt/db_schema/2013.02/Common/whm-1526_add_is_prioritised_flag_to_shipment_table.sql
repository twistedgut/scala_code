-- Add a flag to indicate shipment is prioritised (for picking)
BEGIN;
    ALTER TABLE shipment ADD is_prioritised boolean NOT NULL DEFAULT FALSE;
COMMIT;

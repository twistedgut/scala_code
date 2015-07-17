-- Add a flag when incomplete pick for a shipment_item
BEGIN;
    ALTER TABLE shipment_item ADD is_incomplete_pick boolean NOT NULL DEFAULT FALSE;
COMMIT;

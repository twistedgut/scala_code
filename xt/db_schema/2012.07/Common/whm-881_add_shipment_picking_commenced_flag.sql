-- Add a flag when picking has commenced for a shipment
BEGIN;
    ALTER TABLE shipment ADD is_picking_commenced boolean NOT NULL DEFAULT FALSE;
COMMIT;

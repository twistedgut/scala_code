BEGIN;
    ALTER TABLE shipment ADD COLUMN has_packing_started BOOL;
COMMIT;

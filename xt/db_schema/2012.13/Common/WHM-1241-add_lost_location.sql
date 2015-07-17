-- Add a lost from location to shipment_id

BEGIN;
    ALTER TABLE shipment_item ADD COLUMN
        lost_at_location_id INTEGER REFERENCES location(id)
    ;
COMMIT;

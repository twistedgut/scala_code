BEGIN;

-- FLEX-125
-- Remove all traces of DHL Ground

DROP SEQUENCE dhl_ground_licence_plate_nr;

DROP TABLE manifest_run_number;


-- This column only had a value for the DHL Ground row
-- (INTL: 80916, AM: 28420)
ALTER TABLE carrier DROP COLUMN meter_number;
ALTER TABLE shipping.carrier DROP COLUMN meter_number;


COMMIT;


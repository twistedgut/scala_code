-- Renames the 'licence_plate_number' field to 'tracking_number' to be more sensible

BEGIN WORK;

ALTER TABLE shipment_box
    RENAME COLUMN licence_plate_number TO tracking_number
;

COMMIT WORK;

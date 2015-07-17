-- APS-1452 - Add default value for date columns so there is no need to 
--          - use DateTime->now() within perl when inserting rows 
--          - this will prevent timezone errors when daylight savings occur 

BEGIN;

ALTER TABLE channel_transfer_pick ALTER COLUMN date SET DEFAULT now();
ALTER TABLE channel_transfer_putaway ALTER COLUMN date SET DEFAULT now();
ALTER TABLE shipment_note ALTER COLUMN date SET DEFAULT now();
ALTER TABLE log_channel_transfer ALTER COLUMN date SET DEFAULT now();
ALTER TABLE delivery ALTER COLUMN date SET DEFAULT now();

COMMIT;

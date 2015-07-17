-- Store values passed back from SOS to be passed on to IWS
BEGIN;

    ALTER TABLE shipment ADD COLUMN wms_initial_pick_priority INTEGER;
    ALTER TABLE shipment ADD COLUMN wms_deadline TIMESTAMP WITH TIME ZONE;

    ALTER TABLE shipment ADD COLUMN wms_bump_pick_priority INTEGER;
    ALTER TABLE shipment ADD COLUMN wms_bump_deadline TIMESTAMP WITH TIME ZONE;

COMMIT;
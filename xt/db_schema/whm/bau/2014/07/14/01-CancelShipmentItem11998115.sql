BEGIN;

UPDATE shipment_item SET shipment_item_status_id=(select id from shipment_item_status where status='Packed') WHERE id=11998115;

COMMIT;


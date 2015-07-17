BEGIN;

update shipment_item set shipment_item_status_id = (select id from shipment_item_status where status = 'New') where id = 6689508;

COMMIT;

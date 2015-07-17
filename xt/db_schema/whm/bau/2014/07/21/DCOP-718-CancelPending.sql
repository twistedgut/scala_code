BEGIN;
update shipment_item set shipment_item_status_id=(select id from shipment_item_status where status='Cancelled') where id=6619021;
COMMIT;

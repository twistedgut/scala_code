BEGIN;

update shipment_item set shipment_item_status_id=1 where shipment_id in (3383532, 3383531);

commit;

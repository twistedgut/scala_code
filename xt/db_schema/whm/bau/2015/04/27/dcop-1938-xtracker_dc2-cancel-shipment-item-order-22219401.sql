BEGIN;

-- update shipment item status

 
update shipment_item set shipment_item_status_id = 10, container_id = null -- cancelled
 where id = 8237853
and shipment_item_status_id = 3;

insert into shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id, date)
values (8237853, 10, 1, now());


COMMIT;

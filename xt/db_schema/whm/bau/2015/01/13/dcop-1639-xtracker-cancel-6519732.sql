BEGIN;
 
-- update shipment status
update shipment set shipment_status_id = 4 -- dispatched
    where id = 6519732
    and shipment_status_id = 5; -- cancelled
insert into shipment_status_log (shipment_id, shipment_status_id, operator_id, date)
    values (6519732, 4, 1, now());
 
-- update shipment item status
update shipment_item set shipment_item_status_id = 5 -- dispatched
    where id = 13464406
    and shipment_item_status_id = 10; --cancelled
insert into shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id, date)
    values (13464406, 5, 1, now());
 
 
COMMIT;

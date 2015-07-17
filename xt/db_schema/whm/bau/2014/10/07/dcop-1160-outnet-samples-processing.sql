BEGIN;

insert into shipment_status_log(shipment_id, shipment_status_id, operator_id) values (3361790, 2, 1); 
update shipment set shipment_status_id=2 where id=3361790;

insert into shipment_status_log(shipment_id, shipment_status_id, operator_id) values (3362132, 2, 1); 
update shipment set shipment_status_id=2 where id=3362132;

COMMIT;


BEGIN;

insert into shipment_status_log(shipment_id, shipment_status_id, operator_id) values (3361850, 2, 1); 
update shipment set shipment_status_id=2 where id=3361850;

insert into shipment_status_log(shipment_id, shipment_status_id, operator_id) values (3361857, 2, 1); 
update shipment set shipment_status_id=2 where id=3361857;

insert into shipment_status_log(shipment_id, shipment_status_id, operator_id) values (3361858, 2, 1); 
update shipment set shipment_status_id=2 where id=3361858;

insert into shipment_status_log(shipment_id, shipment_status_id, operator_id) values (3361864, 2, 1); 
update shipment set shipment_status_id=2 where id=3361864;

insert into shipment_status_log(shipment_id, shipment_status_id, operator_id) values (3361865, 2, 1); 
update shipment set shipment_status_id=2 where id=3361865;

COMMIT;


BEGIN;

select setval('shipment_status_id_seq',(select max(id) from shipment_status));
insert into shipment_status (status) values ('Delivered'), ('Delivery Attempted');

COMMIT;

BEGIN;

update shipment_item 
set shipment_item_status_id = (select id from shipment_item_status where status='Cancelled')
where id = 10388209;

insert into shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
values (
    10388209,
    (select id from shipment_item_status where status='Cancelled'),
    (select id from operator where name = 'Application')
);

COMMIT;

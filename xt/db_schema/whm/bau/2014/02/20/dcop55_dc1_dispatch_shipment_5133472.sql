BEGIN;

-- set shipment item status to dispatched (and log)
update shipment_item 
set shipment_item_status_id = (select id from shipment_item_status where status='Dispatched')
where id = 10655801;

insert into shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
values (
    10655801,
    (select id from shipment_item_status where status='Dispatched'),
    (select id from operator where name = 'Application')
);

-- set shipment status to dispatched (and log)
update shipment
set shipment_status_id = (select id from shipment_status where status = 'Dispatched')
where id = 5133472;

insert into shipment_status_log (
    shipment_id, shipment_status_id, operator_id
)
values (
    5133472,
    (select id from shipment_status where status='Dispatched'),
    (select id from operator where name = 'Application')
);
COMMIT;

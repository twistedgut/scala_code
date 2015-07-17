BEGIN;

-- set shipment status to dispatched (and log)
update shipment
set shipment_status_id = (select id from shipment_status where status = 'Dispatched')
where id = 5090620;

insert into shipment_status_log (
    shipment_id, shipment_status_id, operator_id
)
values (
    5090620,
    (select id from shipment_status where status='Dispatched'),
    (select id from operator where name = 'Application')
);
COMMIT;
BEGIN;

-- set return item status to cancelled (and log)
update return_item 
set return_item_status_id = (select id from return_item_status where status='Cancelled')
where id = 3463390;

insert into return_item_status_log (
    return_item_id, return_item_status_id, operator_id
)
values (
    3463390,
    (select id from return_item_status where status='Cancelled'),
    (select id from operator where name = 'Application')
);

-- set shipment item status to dispatched (and log)
update shipment_item 
set shipment_item_status_id = (select id from shipment_item_status where status='Dispatched')
where id = 10361495;

insert into shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
values (
    10361495,
    (select id from shipment_item_status where status='Dispatched'),
    (select id from operator where name = 'Application')
);

-- set return status to complete (and log)
update return
set return_status_id = (select id from return_status where status = 'Cancelled')
where id = 2193821;

insert into return_status_log (
    return_id, return_status_id, operator_id
)
values (
    2193821,
    (select id from return_status where status='Cancelled'),
    (select id from operator where name = 'Application')
);
COMMIT;

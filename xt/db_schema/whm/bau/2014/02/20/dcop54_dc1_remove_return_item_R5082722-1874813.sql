BEGIN;

-- set renumeration status to cancelled
update renumeration
set renumeration_status_id = (select id from renumeration_status where status = 'Cancelled')
where id in (select renumeration_id from link_return_renumeration where return_id = 2174128)
and renumeration_status_id = (select id from renumeration_status where status = 'Pending');

-- set return item status to cancelled (and log)
update return_item 
set return_item_status_id = (select id from return_item_status where status='Cancelled')
where id = 3432682;

insert into return_item_status_log (
    return_item_id, return_item_status_id, operator_id
)
values (
    3432682,
    (select id from return_item_status where status='Cancelled'),
    (select id from operator where name = 'Application')
);

-- set shipment item status to dispatched (and log)
update shipment_item 
set shipment_item_status_id = (select id from shipment_item_status where status='Dispatched')
where id = 10558534;

insert into shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
values (
    10558534,
    (select id from shipment_item_status where status='Dispatched'),
    (select id from operator where name = 'Application')
);

-- set return status to complete (and log)
update return
set return_status_id = (select id from return_status where status = 'Complete')
where id = 2174128;

insert into return_status_log (
    return_id, return_status_id, operator_id
)
values (
    2174128,
    (select id from return_status where status='Complete'),
    (select id from operator where name = 'Application')
);
COMMIT;

BEGIN;

insert into shipment_item_status_log(shipment_item_id,shipment_item_status_id,operator_id)
select si.id,(select id from shipment_item_status where status = 'Cancelled'),1
from shipment_item si
where
    shipment_item_status_id = (select id from shipment_item_status where status = 'Cancel Pending')
    and id in (
        6109045
    )
;

 
update shipment_item
set shipment_item_status_id = (select id from shipment_item_status where status = 'Cancelled')
where
    shipment_item_status_id = (select id from shipment_item_status where status = 'Cancel Pending')
    and id in (
        6109045
    )
;

COMMIT;

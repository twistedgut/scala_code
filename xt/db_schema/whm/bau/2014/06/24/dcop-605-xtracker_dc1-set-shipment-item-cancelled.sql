BEGIN;

insert into shipment_item_status_log(shipment_item_id,shipment_item_status_id,operator_id)
select si.id,(select id from shipment_item_status where status = 'Cancelled'),1
from shipment_item si
where
    shipment_item_status_id = (select id from shipment_item_status where status = 'Cancel Pending')
    and id in (
        11442358,
        11442359,
        11459721,
        11459722
    )
;

 
update shipment_item
set shipment_item_status_id = (select id from shipment_item_status where status = 'Cancelled')
where
    shipment_item_status_id = (select id from shipment_item_status where status = 'Cancel Pending')
    and id in (
        11442358,
        11442359,
        11459721,
        11459722
    )
;

COMMIT;

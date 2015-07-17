BEGIN;

select si.shipment_id,si.id,si.shipment_item_status_id,ci.date
from shipment_item si
join cancelled_item ci on ci.shipment_item_id=si.id
where si.shipment_item_status_id not in (9,10)
order by si.shipment_item_status_id asc,ci.date asc;

select si.shipment_item_status_id,s.status,count(*)
from shipment_item si
join cancelled_item ci on ci.shipment_item_id=si.id
join shipment_item_status s on si.shipment_item_status_id=s.id
where si.shipment_item_status_id not in (9,10)
group by si.shipment_item_status_id,s.status;

delete from cancelled_item ci
using shipment_item si
where ci.shipment_item_id=si.id and si.shipment_item_status_id in (1,2);

COMMIT;

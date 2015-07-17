\pset format unaligned
\pset fieldsep ' '
\pset tuples_only on

BEGIN;

-- SHIPMENTS

-- picked already?

select 'Shipments (at least partially) picked and not dispatched:',count(distinct shipment.id)
from shipment
join shipment_item on shipment.id = shipment_item.shipment_id
where shipment_item_status_id in (3,4,9,13) -- picked, packed, cancel pending, PE
  and shipment.shipment_status_id in (1,2,3,9); -- processing and holds

-- if not picked, but selected, pretend we cancelled them

select 'Shipments selected and not completely picked:',count(distinct shipment.id)
from shipment
join shipment_item on shipment.id = shipment_item.shipment_id
where shipment_item_status_id in (2) -- selected
  and shipment.shipment_status_id in (1,2,3,9); -- processing and holds

-- containers

select 'Containers with shipment items in them:',count(distinct container_id)
from shipment
join shipment_item on shipment.id = shipment_item.shipment_id
where shipment_item_status_id in (3,4,9,13) -- picked, packed, cancel pending, PE
  and shipment.shipment_status_id in (1,2,3,9); -- processing and holds

select 'Containers with orphaned items in them:',count(distinct container_id)
from orphan_item;

-- STOCK PROCESSES

select 'Stock process groups being put away:',count(distinct group_id)
from stock_process
where status_id in (2,3,4) -- approved, bag&tag, putaway
  and quantity > 0 -- those with 0 are ignorable
  and not complete;

-- RETURNS

select 'Returns being put away:',count(distinct return_id)
from return_item
join return on return.id=return_item.return_id
where return_item_status_id in (4,5,6) -- qcfail reject, qcfail accept, qcpass
and return_status_id in (2);

-- CHANNEL TRANSFERS

select 'Products in channel transfers selected and not completed:', count(distinct product_id)
from channel_transfer
where status_id in (2,3,4); -- selected, incomplete pick, picked

ROLLBACK;

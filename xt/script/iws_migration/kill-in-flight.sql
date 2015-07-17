DO NOT run this on live. -- It's for testing.

BEGIN;

-- SHIPMENTS

alter table shipment_item disable trigger canc_qty_tgr;
alter table shipment_item disable trigger prepick_qty_tgr;

-- if picked already, pretend we shipped them

update shipment set shipment_status_id = 4
from shipment_item
where shipment.id = shipment_id
and shipment_item_status_id in (3,4,9,13);

update shipment_item set shipment_item_status_id = 5
where shipment_item_status_id in (3,4,9,13);

-- if not picked, but selected, pretend we cancelled them

update shipment set shipment_status_id = 5
from shipment_item
where shipment.id = shipment_id
and shipment_item_status_id in (2);

update shipment_item set shipment_item_status_id = 10
where shipment_item_status_id in (2);

alter table shipment_item enable trigger canc_qty_tgr;
alter table shipment_item enable trigger prepick_qty_tgr;

-- orphan items: have them disappear

delete from orphan_item;

-- STOCK PROCESSES

-- let's pretend we've put away everything

update stock_process set status_id = 4, complete = true
where status_id in (2,3,4);

-- RETURNS

-- let's pretend we've put away everything

update return_item set return_item_status_id = 7
where return_item_status_id in (3,4,5,6);

-- CHANNEL TRANSFERS

-- rollback half-done transfers

-- -- this one should update very few quantities, let's ignore the
-- -- side-effects for now

update quantity q set channel_id=pcf.channel_id
 from product_channel pcf
  join product_channel pct on pcf.product_id =  pct.product_id
                          and pcf.channel_id != pct.channel_id
  join variant v on pcf.product_id=v.product_id
 where pcf.transfer_status_id=3
   and pct.transfer_status_id=1
   and pcf.channel_id != q.channel_id
   and v.id=q.variant_id;

update channel_transfer set status_id=1
 where status_id in (2,3,4);

ROLLBACK;

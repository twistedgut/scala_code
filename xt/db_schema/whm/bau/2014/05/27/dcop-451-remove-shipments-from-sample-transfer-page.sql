
--
-- DCOP-451: Remove Shipments from sample transfer page
--
-- Two shipments appear on http://xt-us.net-a-porter.com/StockControl/Sample
-- This patch will remove them
--

BEGIN;

update shipment
    set shipment_status_id = (select id from shipment_status where status = 'Dispatched')
    where id in (2985901, 2985904);

update shipment_item
    set shipment_item_status_id = (select id from shipment_item_status where status = 'Dispatched')
    where shipment_id in (2985901, 2985904);

COMMIT;

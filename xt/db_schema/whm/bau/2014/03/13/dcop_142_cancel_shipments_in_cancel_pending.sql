-- DCOP-142 Cancel shipment items

BEGIN;

update shipment_item
set shipment_item_status_id = (select id from shipment_item_status where status = 'Cancelled')
where
    shipment_item_status_id = (select id from shipment_item_status where status = 'Cancel Pending')
    and id in (
        5463896,
        5510846,
        5536961,
        5598567,
        5609999,
        5612660,
        5630696,
        5480073,
        5539696
    )
;

COMMIT;

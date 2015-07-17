BEGIN;

update shipment_item
set
	shipment_item_status_id = (select id from shipment_item_status where status = 'Cancelled')
where
    shipment_item_status_id = (select id from shipment_item_status where status = 'Cancel Pending')
and
	id = 6360315;

COMMIT;

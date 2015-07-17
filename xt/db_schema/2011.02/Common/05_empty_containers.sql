BEGIN;

UPDATE shipment_item
SET container_id = NULL
WHERE shipment_item_status_id IN (4,5,6,7,8,10,11,12)
AND container_id IS NOT NULL; 

-- Packed, Dispatched, Return Pending, Return Received, Returned, Cancelled, Lost, Undelivered
-- no item in any of these states should be in a container

COMMIT;


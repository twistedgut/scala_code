-- DC1 unblock shipment item from being cancelled

BEGIN;

    -- Remove entry for shipment item in cancelled_item
    DELETE from cancelled_item WHERE shipment_item_id = 11806730;

    -- Remove entry from shipment_item_status_log for shipment item
    DELETE from shipment_item_status_log
    WHERE shipment_item_id = 11806730 
    AND shipment_item_status_id = (
        SELECT id from shipment_item_status 
        WHERE status = 'Cancelled'
    );

COMMIT;

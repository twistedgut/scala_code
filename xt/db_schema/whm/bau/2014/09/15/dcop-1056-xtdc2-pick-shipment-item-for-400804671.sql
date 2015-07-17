BEGIN;

    UPDATE shipment_item SET container_id = 'T0005522', shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status='Picked'
    )
    WHERE id = 6824332;

COMMIT;

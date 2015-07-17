BEGIN;

    UPDATE shipment_item SET container_id = null
    WHERE id = 5775453;

    UPDATE container SET place = null, status_id = (
        SELECT id FROM container_status WHERE name = 'Available'
    )
    WHERE id = 'T0016646';


COMMIT;

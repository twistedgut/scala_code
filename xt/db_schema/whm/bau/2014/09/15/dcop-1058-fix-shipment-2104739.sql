BEGIN;

    UPDATE shipment_item SET container_id = null, shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status='Cancelled'
    )
    WHERE id = 4487946;

    INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
        VALUES (
            4487946,
            (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
            (SELECT id FROM operator WHERE name = 'Application')
        )
    ;

    UPDATE container SET place = null, status_id = (
        SELECT id FROM container_status WHERE name = 'Available'
    )
    WHERE id = 'M015447';


COMMIT;

-- DC2 delete shipment and shipment items

BEGIN;
    -- Update shipment_status to 'Cancelled'
    UPDATE shipment
        SET shipment_status_id=(
            SELECT id FROM shipment_status WHERE status='Cancelled'
        )
        WHERE id in ( 3019128 )
    ;
    -- Update the logs
    INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id) VALUES
		(3019128, (SELECT id FROM shipment_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application'));

    -- Update shipment_item_status to 'Cancelled'
    UPDATE shipment_item
        SET shipment_item_status_id=(
            SELECT id FROM shipment_item_status WHERE status='Cancelled'
        )
        WHERE shipment_id in ( 3019128 )
    ;
    -- Update the logs, possibly multiple copies
    INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id) VALUES
		(6290417, (SELECT id FROM shipment_item_status WHERE status='Cancelled'), (SELECT id FROM operator WHERE name='Application'));

COMMIT;

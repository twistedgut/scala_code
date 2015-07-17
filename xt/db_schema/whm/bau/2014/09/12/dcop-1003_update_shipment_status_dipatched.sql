BEGIN;

    -- Update shipment_status
    UPDATE shipment
        SET shipment_status_id=(
            SELECT id FROM shipment_status WHERE status='Dispatched')
        WHERE id in(5894247);
    
    -- Update the logs
    INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id)
    VALUES (
        5894247,
        (SELECT id FROM shipment_status WHERE status = 'Dispatched'),
        (SELECT id FROM operator WHERE name = 'Application')
    );

COMMIT;

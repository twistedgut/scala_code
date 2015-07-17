BEGIN;

    -- Update the logs and update the status (but only if shipment is still on hold)
    INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id)
    SELECT id,
    (SELECT id FROM shipment_status WHERE status='Processing'),
    (SELECT id FROM operator WHERE name='Application')  
    FROM shipment WHERE id = 3224120 AND shipment_status_id=(SELECT id FROM shipment_status WHERE status='Hold');

    UPDATE shipment SET shipment_status_id=(SELECT id FROM shipment_status WHERE status='Processing')
    WHERE id = 3224120 AND shipment_status_id=(SELECT id FROM shipment_status WHERE status='Hold');
    
    -- Update the logs and update the status (but only if shipment is still on hold)
    INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id)
    SELECT id,
    (SELECT id FROM shipment_status WHERE status='Processing'),
    (SELECT id FROM operator WHERE name='Application')  
    FROM shipment WHERE id = 3283609 AND shipment_status_id=(SELECT id FROM shipment_status WHERE status='Hold');

    UPDATE shipment SET shipment_status_id=(SELECT id FROM shipment_status WHERE status='Processing')
    WHERE id = 3283609 AND shipment_status_id=(SELECT id FROM shipment_status WHERE status='Hold');
    
    -- Update the logs and update the status (but only if shipment is still on hold)
    INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id)
    SELECT id,
    (SELECT id FROM shipment_status WHERE status='Processing'),
    (SELECT id FROM operator WHERE name='Application')  
    FROM shipment WHERE id = 3208136 AND shipment_status_id=(SELECT id FROM shipment_status WHERE status='Hold');

    UPDATE shipment SET shipment_status_id=(SELECT id FROM shipment_status WHERE status='Processing')
    WHERE id = 3208136 AND shipment_status_id=(SELECT id FROM shipment_status WHERE status='Hold');
    
    

COMMIT;

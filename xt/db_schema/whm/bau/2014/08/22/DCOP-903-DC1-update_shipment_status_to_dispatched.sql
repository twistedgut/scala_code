-- Update status of shipment to 'Dispatched'
BEGIN;
    UPDATE shipment
        SET shipment_status_id = (SELECT id FROM shipment_status WHERE status = 'Dispatched')
        WHERE id = 5893921;
    INSERT INTO shipment_status_log
        ( shipment_id, shipment_status_id, operator_id )
    VALUES (
        5893921,
        (SELECT id FROM shipment_status WHERE status = 'Dispatched'),
        (SELECT id FROM operator WHERE name = 'Application')
    );
COMMIT;

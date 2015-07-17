BEGIN;

UPDATE shipment 
SET shipment_status_id = (
    SELECT id from shipment_status where status = 'Processing' 
)
WHERE id = 6173680;

INSERT INTO shipment_status_log( shipment_id, shipment_status_id, operator_id, date ) 
    VALUES ( 
        6173680, 
        (SELECT id from shipment_status where status = 'Processing'),
        (SELECT id FROM operator WHERE name='Application'),
        NOW()
    );

UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Selected'
    )
WHERE id = 12774158;

INSERT INTO shipment_item_status_log( shipment_item_id, shipment_item_status_id, operator_id, date ) 
    VALUES ( 
        12774158, 
        (SELECT id FROM shipment_item_status WHERE status = 'Selected'),
        (SELECT id FROM operator WHERE name='Application'),
        NOW()
    );

DELETE FROM shipment_hold where shipment_id = 6173680;

COMMIT;

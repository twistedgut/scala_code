BEGIN;
  
UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    ), container_id = null
    WHERE id = 6971372
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancel Pending'
    );
 
INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        6971372,
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    )
;
 
COMMIT;

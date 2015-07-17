BEGIN;
  
UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Picked'
    ), container_id = 'T0062318'
    WHERE id = 7132922
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Selected'
    );
 
INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        7132922,
        (SELECT id FROM shipment_item_status WHERE status = 'Picked'),
        (SELECT id FROM operator WHERE name = 'Application')
    );

UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Picked'
    ), container_id = 'T0062912'
    WHERE id = 7137170
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Selected'
    );
 
INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        7137170,
        (SELECT id FROM shipment_item_status WHERE status = 'Picked'),
        (SELECT id FROM operator WHERE name = 'Application')
    );

COMMIT;

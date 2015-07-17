BEGIN;
  
UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    ), container_id = null
    WHERE id = 6763421
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancel Pending'
    );
 
INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        6763421,
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    )
;
 
UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    ), container_id = null
    WHERE id = 6969698
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancel Pending'
    );
 
INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        6969698,
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    )
;
 
UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    ), container_id = null
    WHERE id = 6964702
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancel Pending'
    );
 
INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        6964702,
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    )
;
 
UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    ), container_id = null
    WHERE id = 6974126
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancel Pending'
    );
 
INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        6974126,
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    )
;
 
UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    ), container_id = null
    WHERE id = 6960061
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancel Pending'
    );
 
INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        6960061,
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    )
;
 
UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    ), container_id = null
    WHERE id = 6509710
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancel Pending'
    );
 
INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        6509710,
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    )
;
 
COMMIT;

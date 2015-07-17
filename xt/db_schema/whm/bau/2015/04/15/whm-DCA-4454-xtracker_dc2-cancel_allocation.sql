BEGIN;

UPDATE shipment_item
    SET shipment_item_status_id = (SELECT id FROM shipment_item_status WHERE status = 'Cancelled')
    WHERE id=7844410;

INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        7844410,
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    );

UPDATE allocation_item
    SET status_id = (SELECT id FROM allocation_item_status WHERE status = 'cancelled')
    WHERE allocation_id=1703575;

INSERT INTO allocation_item_log (operator_id, allocation_status_id, allocation_item_status_id, allocation_item_id)
    VALUES (
        (SELECT id FROM operator WHERE name = 'Application'),
        (SELECT id FROM allocation_status WHERE status = 'picked'),
        (SELECT id FROM allocation_item_status WHERE status = 'cancelled'),
        1703575
    );

UPDATE allocation
    SET status_id = (SELECT id FROM allocation_status WHERE status = 'picked')
    WHERE id = 1703575;

COMMIT;

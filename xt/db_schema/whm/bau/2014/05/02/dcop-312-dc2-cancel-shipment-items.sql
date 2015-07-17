BEGIN;

UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    )
    WHERE id IN ('5059534', '4939928', '4990477')
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'New'
    );

INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        '5059534',
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    ), (
        '4939928',
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    ), (
        '4990477',
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    )

;

COMMIT;

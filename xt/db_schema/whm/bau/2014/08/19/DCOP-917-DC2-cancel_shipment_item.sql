-- Item is stuck in cancel pending, cancel it

BEGIN;
UPDATE shipment_item
    SET shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancelled'
    )
    WHERE id = 5058452
    AND shipment_item_status_id = (
        SELECT id FROM shipment_item_status WHERE status = 'Cancel Pending'
    );

INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        5058452,
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    )
;
COMMIT;

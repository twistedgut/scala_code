-- Item is stuck in cancel pending, cancel it

BEGIN;
INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES (
        6619021,
        (SELECT id FROM shipment_item_status WHERE status = 'Cancelled'),
        (SELECT id FROM operator WHERE name = 'Application')
    )
;
COMMIT;

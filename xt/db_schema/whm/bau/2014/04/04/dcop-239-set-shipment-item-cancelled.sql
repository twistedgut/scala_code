BEGIN;

-- Set the shipment item status to cancelled and log it

UPDATE shipment_item
    SET shipment_item_status_id=(
        SELECT id FROM shipment_item_status WHERE status='Cancelled'
    )
WHERE id = 10871367
AND shipment_id = 5238234
;

INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id)
     VALUES (
         10871367,
         (SELECT id FROM shipment_item_status WHERE status='Cancelled'),
         (SELECT id FROM operator WHERE name='Application')
     )
;

COMMIT;

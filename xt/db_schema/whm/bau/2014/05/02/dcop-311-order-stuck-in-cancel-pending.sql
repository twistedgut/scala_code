BEGIN;

UPDATE shipment_item
    SET shipment_item_status_id = ( SELECT id FROM shipment_item_status where status = 'Cancelled' )
    WHERE shipment_item_status_id = ( SELECT id FROM shipment_item_status where status = 'Cancel Pending')
    AND id = 2903603;

INSERT INTO shipment_item_status_log
    ( shipment_item_id, shipment_item_status_id, operator_id )
        VALUES
    ( 2903603, ( SELECT id FROM shipment_item_status where status = 'Cancelled' ), ( SELECT id FROM operator WHERE name = 'Application' ) )
;

COMMIT;

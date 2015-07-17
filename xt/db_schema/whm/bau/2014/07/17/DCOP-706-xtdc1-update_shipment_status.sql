-- This shipment has already been dispatched, the items are already in the
-- correct state, just mark the shipment as 'Dispatched'

BEGIN;
    UPDATE shipment
        SET shipment_status_id = ( SELECT id FROM shipment_status WHERE status = 'Dispatched' )
        WHERE id = 5799737;

    INSERT INTO shipment_status_log ( shipment_id, shipment_status_id, operator_id )
        VALUES (
            5799737,
            ( SELECT id FROM shipment_status WHERE status = 'Dispatched' ),
            ( SELECT id FROM operator WHERE name = 'Application' )
        );
COMMIT;

-- DCOP-108 Cancel shipment

BEGIN;

CREATE OR REPLACE FUNCTION dcop_108_cancel(val_shipment_id INTEGER) RETURNS VOID AS $$

DECLARE
    val_shipment_item_id INTEGER;
    val_shipment_item_status_id INTEGER;
    val_shipment_status_id INTEGER;
    val_operator_id INTEGER;

BEGIN

    SELECT id INTO val_operator_id FROM operator WHERE name = 'Application';

    -- Cancel the shipment item
    SELECT id INTO val_shipment_item_status_id FROM shipment_item_status WHERE status = 'Cancelled';
    UPDATE shipment_item
        SET shipment_item_status_id = val_shipment_item_status_id
        WHERE shipment_id = val_shipment_id
        RETURNING id INTO val_shipment_item_id;

    -- Log the item cancellation
    INSERT INTO shipment_item_status_log
        (shipment_item_id, shipment_item_status_id, operator_id)
    VALUES
        (val_shipment_item_id, val_shipment_item_status_id, val_operator_id);

    -- Cancel the shipment
    SELECT id INTO val_shipment_status_id FROM shipment_status WHERE status = 'Cancelled';
    UPDATE shipment
        SET shipment_status_id = val_shipment_status_id
        WHERE id = val_shipment_id;

    -- Log the shipment cancellation
    INSERT INTO shipment_status_log
        (shipment_id, shipment_status_id, operator_id)
    VALUES
        (val_shipment_id, val_shipment_status_id, val_operator_id);

END;
$$ LANGUAGE plpgsql;

SELECT dcop_108_cancel(5159852);
DROP FUNCTION dcop_108_cancel(int);

COMMIT;

BEGIN;
    -- Update shipment_item_status to 'Cancelled'
    UPDATE shipment_item
        SET shipment_item_status_id=(
            SELECT id FROM shipment_item_status WHERE status='Cancelled'
        )
        WHERE id = 6536891;
    ;
    -- Update the logs
    INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id) VALUES
		(6536891, (SELECT id FROM shipment_item_status where status='Cancelled'), (SELECT id FROM operator WHERE name='Application'));


COMMIT;

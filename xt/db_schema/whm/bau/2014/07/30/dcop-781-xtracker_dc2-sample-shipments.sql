-- Fix sample shipments affected by AMQ bug (DCOP-651)

BEGIN;
    -- shipment 3193558
    -- Update shipment_item_status to 'Picked'
    UPDATE shipment_item
        SET shipment_item_status_id=(
            SELECT id FROM shipment_item_status WHERE status='Picked'
        ),
        container_id = 'T0012568'
        WHERE id = 6637606;
    ;
    -- Update the logs
    INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id) VALUES
		(6637606, (SELECT id FROM shipment_item_status where status='Picked'), (SELECT id FROM operator WHERE name='Application'));
    -- Take shipment off hold
    UPDATE shipment
        SET shipment_status_id = (SELECT id FROM shipment_status WHERE status = 'Processing')
        WHERE id = 3193558;
    INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id) VALUES
        (3193558, (SELECT id FROM shipment_status WHERE status='Processing'), (SELECT id FROM operator WHERE name='Application'));




    -- shipment 3162934
    -- Update shipment_item_status to 'Picked'
    UPDATE shipment_item
        SET shipment_item_status_id=(
            SELECT id FROM shipment_item_status WHERE status='Picked'
        ),
        container_id = 'T0020798'
        WHERE id = 6578130;
    ;
    -- Update the logs
    INSERT INTO shipment_item_status_log (shipment_item_id, shipment_item_status_id, operator_id) VALUES
		(6578130, (SELECT id FROM shipment_item_status where status='Picked'), (SELECT id FROM operator WHERE name='Application'));
    -- Take shipment off hold
    UPDATE shipment
        SET shipment_status_id = (SELECT id FROM shipment_status WHERE status = 'Processing')
        WHERE id = 3162934;
    INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id) VALUES
        (3162934, (SELECT id FROM shipment_status WHERE status='Processing'), (SELECT id FROM operator WHERE name='Application'));

COMMIT;

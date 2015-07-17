--
-- DC1 Only
--

-- CANDO-8005: Reset Shipment 5500818 from Lost to Dispatched

BEGIN WORK;

-- Update shipment_status
UPDATE shipment
    SET shipment_status_id=(
        SELECT id FROM shipment_status WHERE status='Dispatched')
    WHERE id in(5500818);

-- Update the logs
INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id)
SELECT id,
   (SELECT id FROM shipment_status WHERE status='Dispatched'),
      (SELECT id FROM operator WHERE name='Application')
FROM shipment WHERE id in(5500818);

-- Update shipment_item_status
UPDATE shipment_item
    SET shipment_item_status_id=
       (SELECT id FROM shipment_item_status WHERE status='Dispatched')
    WHERE shipment_id in(5500818);

-- Update the logs, possibly multiple copies
INSERT INTO shipment_item_status_log(shipment_item_id, shipment_item_status_id, operator_id)
SELECT id,
   (SELECT id FROM shipment_item_status WHERE status='Dispatched'),
      (SELECT id FROM operator WHERE name='Application')
FROM shipment_item WHERE shipment_id in(5500818);

INSERT INTO shipment_note ( shipment_id, note_type_id, operator_id, note ) VALUES (
    5500818,
    ( SELECT id FROM note_type WHERE code = 'SHP' ),
    ( SELECT id FROM operator WHERE name='Application' ),
    'BAU (CANDO-8005): Have Reset Shipment & Shipment Item Statuses from ''Lost'' to ''Dispatched'''
);

COMMIT WORK;

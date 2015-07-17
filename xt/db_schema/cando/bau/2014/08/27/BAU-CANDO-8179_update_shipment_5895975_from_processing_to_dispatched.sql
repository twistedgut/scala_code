--
-- DC1 Only
--

-- CANDO-8179: Reset Shipment Status from Processing to Dispatched

BEGIN;

-- Create Shipment Status logs

INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id)
SELECT  id,
        (SELECT id FROM shipment_status WHERE status='Dispatched'),
        (SELECT id FROM operator WHERE name='Application')
FROM    shipment WHERE id = 5895975
AND     shipment_status_id = (
    SELECT id FROM shipment_status WHERE status='Processing'
);

-- Insert Shipment Notes

INSERT INTO shipment_note ( shipment_id, note_type_id, operator_id, note )
SELECT  id,
        ( SELECT id FROM note_type WHERE code = 'SHP' ),
        ( SELECT id FROM operator WHERE name='Application' ),
        'BAU (CANDO-8179): Have Reset Shipment Status from ''Processing'' to ''Dispatched'''
FROM    shipment
WHERE   id = 5895975
AND     shipment_status_id = (
    SELECT id FROM shipment_status WHERE status='Processing'
);

-- Update Shipment Status

UPDATE shipment
    SET shipment_status_id=(
        SELECT id FROM shipment_status WHERE status='Dispatched')
WHERE   id = 5895975
AND     shipment_status_id = (
    SELECT id FROM shipment_status WHERE status='Processing'
);

COMMIT;

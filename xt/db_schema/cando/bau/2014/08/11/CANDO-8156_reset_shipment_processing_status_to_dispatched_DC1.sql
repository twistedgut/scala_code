--
-- DC1 Only
--

-- CANDO-8156: Reset Shipments from Processing to Dispatched

BEGIN WORK;

-- create Shipment Status logs
INSERT INTO shipment_status_log (shipment_id, shipment_status_id, operator_id)
SELECT  id,
        (SELECT id FROM shipment_status WHERE status='Dispatched'),
        (SELECT id FROM operator WHERE name='Application')
FROM    shipment WHERE id IN (
    5895502,
    5892925,
    5896297,
    5896271
)
AND     shipment_status_id = (
    SELECT id FROM shipment_status WHERE status='Processing'
);

-- insert Shipment Notes
INSERT INTO shipment_note ( shipment_id, note_type_id, operator_id, note )
SELECT  id,
        ( SELECT id FROM note_type WHERE code = 'SHP' ),
        ( SELECT id FROM operator WHERE name='Application' ),
        'BAU (CANDO-8156): Have Reset Shipment Status from ''Processing'' to ''Dispatched'''
FROM    shipment
WHERE   id IN (
    5895502,
    5892925,
    5896297,
    5896271
)
AND     shipment_status_id = (
    SELECT id FROM shipment_status WHERE status='Processing'
);

-- Update Shipment Status
UPDATE shipment
    SET shipment_status_id=(
        SELECT id FROM shipment_status WHERE status='Dispatched')
WHERE   id IN (
    5895502,
    5892925,
    5896297,
    5896271
)
AND     shipment_status_id = (
    SELECT id FROM shipment_status WHERE status='Processing'
);

COMMIT WORK;

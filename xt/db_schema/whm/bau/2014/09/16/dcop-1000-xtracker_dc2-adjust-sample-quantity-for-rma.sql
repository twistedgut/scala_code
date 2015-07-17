BEGIN;

-- Replace item that has been deleted in quantity table and update log

INSERT INTO quantity (variant_id, location_id, quantity, channel_id, status_id) VALUES ( 
    2343235, 
    (SELECT id from location where location = 'Sample Room'),
    1,
    (SELECT id FROM channel WHERE name = 'theOutnet.com'),
    (SELECT id from flow.status WHERE name = 'Sample')
);

INSERT INTO log_sample_adjustment (sku, location_name, operator_name, channel_id, notes, delta, balance) VALUES (
    '314022-098',
    'Sample Room',
    'Application',
    (SELECT id FROM channel WHERE name = 'theOutnet.com'),
    'Replacing stock so RMA can be created as the item has been found',
    1,
    1
);

-- Update shipment item as being lost so the operator can update as found and then create RMA

UPDATE shipment_item
SET shipment_item_status_id = (SELECT id FROM shipment_item_status WHERE status = 'Lost'),
    lost_at_location_id = (SELECT id from location where location = 'Sample Room')
WHERE id = 4323748
AND shipment_id = 2013871
AND variant_id = 2343235;

COMMIT;

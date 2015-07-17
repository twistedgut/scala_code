BEGIN;

INSERT INTO quantity (variant_id, location_id, quantity, channel_id, status_id) values (
    4177641,
    (SELECT id FROM location WHERE location = 'Sample Room'),
    1,
    (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM'),
    (SELECT id FROM flow.status WHERE name = 'Sample')
);

INSERT INTO log_sample_adjustment (
        sku, location_name, operator_name, channel_id, notes, delta, balance
)
SELECT v.product_id || '-' || sku_padding(v.size_id), l.location, 'Application', 
       q.channel_id, 'Adjusted by BAU to reverse incorrect Lost adjustment', 1, 0
FROM variant v join quantity q ON v.id=q.variant_id JOIN location l ON q.location_id=l.id
WHERE l.location = 'Sample Room' 
AND q.status_id = (SELECT id FROM flow.status WHERE name = 'Sample')
AND q.quantity = 1
AND v.id = 4177641;

COMMIT;

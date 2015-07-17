BEGIN;

INSERT INTO prl_delivery_destination (id, prl_id, name, message_name, description)
SELECT 1, id, 'GOH Direct', 'direct_lane',
    'Lane to use for delivering allocations that can be put straight into empty totes to send to packing'
FROM prl WHERE name = 'GOH';

INSERT INTO prl_delivery_destination (id, prl_id, name, message_name, description)
SELECT 2, id, 'GOH Integration', 'integration_lane',
    'Lane to use for allocations that should be integrated with sibling allocations arriving in totes from DCD'
FROM prl WHERE name = 'GOH';

COMMIT;

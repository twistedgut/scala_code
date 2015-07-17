-- whm-4627: add DHL account numbers to the shipping account

BEGIN;

UPDATE shipping_account SET account_number = 846291686
    WHERE carrier_id = (SELECT id FROM carrier WHERE name = 'DHL Express')
    AND shipping_class_id = (SELECT id FROM shipping_class WHERE name = 'International')
    AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM');

UPDATE shipping_account SET account_number = 845776403
    WHERE carrier_id = (SELECT id FROM carrier WHERE name = 'DHL Express')
    AND shipping_class_id = (SELECT id FROM shipping_class WHERE name = 'International')
    AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com');

UPDATE shipping_account SET account_number = 846291686
    WHERE carrier_id = (SELECT id FROM carrier WHERE name = 'DHL Express')
    AND shipping_class_id = (SELECT id FROM shipping_class WHERE name = 'International Road')
    AND channel_id = (SELECT id FROM channel WHERE name = 'NET-A-PORTER.COM');

UPDATE shipping_account SET account_number = 845888117
    WHERE carrier_id = (SELECT id FROM carrier WHERE name = 'DHL Express')
    AND shipping_class_id = (SELECT id FROM shipping_class WHERE name = 'International Road')
    AND channel_id = (SELECT id FROM channel WHERE name = 'MRPORTER.COM');

UPDATE shipping_account SET account_number = 845776403
    WHERE carrier_id = (SELECT id FROM carrier WHERE name = 'DHL Express')
    AND shipping_class_id = (SELECT id FROM shipping_class WHERE name = 'International Road')
    AND channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com');

COMMIT;


-- FLEX-763 - Update carrier and shipping_charge to allow for a midnight DHL pickup

BEGIN;


-- Before: 17:00:00
UPDATE carrier SET last_pickup_daytime = '23:30' WHERE name = 'DHL Express';



-- Before: 13:00:00
UPDATE shipping_charge
    SET latest_nominated_dispatch_daytime = '17:00'
    WHERE sku IN ('9000216-001');



COMMIT;


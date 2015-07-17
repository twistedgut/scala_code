--
-- SHIP-384: Enable "Next Day" shipping to Germany
--

BEGIN;

-- turn on the shipping SKU in XT
UPDATE shipping_charge SET is_enabled = 't' WHERE sku = '9000524-004';

-- dis-associate the "Express" option from Germany
DELETE
FROM   country_shipping_charge
WHERE  country_id         = ( SELECT id FROM country WHERE code = 'DE' )
AND    shipping_charge_id = ( SELECT id FROM shipping_charge WHERE sku = '900008-001' );

COMMIT;

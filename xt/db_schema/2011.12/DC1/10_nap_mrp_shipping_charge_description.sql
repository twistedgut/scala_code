BEGIN;

-- FLEX-182, FLEX-34
-- Make the SKU descriptions match the front end.

UPDATE shipping_charge SET description = 'European Express'  WHERE sku = '900008-001';
UPDATE shipping_charge SET description = 'European Standard' WHERE sku = '9000203-001';
UPDATE shipping_charge SET description = 'European Standard' WHERE sku = '9000204-001';
UPDATE shipping_charge SET description = 'European Express'  WHERE sku = '910008-001';
UPDATE shipping_charge SET description = 'European Standard' WHERE sku = '9010203-001';
UPDATE shipping_charge SET description = 'European Standard' WHERE sku = '9010204-001';

COMMIT;

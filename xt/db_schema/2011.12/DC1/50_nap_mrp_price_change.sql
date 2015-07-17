BEGIN;

-- FLEX-186
-- Set shipping price for NAP, MRP International Road to £12

UPDATE shipping_charge SET charge = 12.00 WHERE sku = '9000203-001';
UPDATE shipping_charge SET charge = 12.00 WHERE sku = '9000204-001';
UPDATE shipping_charge SET charge = 12.00 WHERE sku = '9010203-001';
UPDATE shipping_charge SET charge = 12.00 WHERE sku = '9010204-001';

COMMIT;

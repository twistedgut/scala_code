
-- FLEX-186

-- This is to remove any extra shipping_charge skus that may have
-- sneaked in from removing SQL patch files without dealing with the
-- fact that it was applied to some environments before the removal.
-- 
-- This should be a no-op in envs where the removed SQL patch were
-- never applied.


BEGIN;


DELETE FROM shipping_charge where sku = '9000210-001';
DELETE FROM shipping_charge where sku = '900166-001';
DELETE FROM shipping_charge where sku = '900194-001';
DELETE FROM shipping_charge where sku = '900158-001';
DELETE FROM shipping_charge where sku = '900142-001';
DELETE FROM shipping_charge where sku = '900190-001';
DELETE FROM shipping_charge where sku = '900129-001';
DELETE FROM shipping_charge where sku = '900168-001';
DELETE FROM shipping_charge where sku = '900130-001';
DELETE FROM shipping_charge where sku = '900170-001';
DELETE FROM shipping_charge where sku = '900135-001';
DELETE FROM shipping_charge where sku = '900160-001';
DELETE FROM shipping_charge where sku = '900146-001';
DELETE FROM shipping_charge where sku = '900136-001';
DELETE FROM shipping_charge where sku = '900138-001';
DELETE FROM shipping_charge where sku = '900113-001';
DELETE FROM shipping_charge where sku = '900182-001';
DELETE FROM shipping_charge where sku = '9000216-001';
DELETE FROM shipping_charge where sku = '900184-001';
DELETE FROM shipping_charge where sku = '900198-001';
DELETE FROM shipping_charge where sku = '900156-001';
DELETE FROM shipping_charge where sku = '900131-001';
DELETE FROM shipping_charge where sku = '900148-001';
DELETE FROM shipping_charge where sku = '900126-001';
DELETE FROM shipping_charge where sku = '900178-001';
DELETE FROM shipping_charge where sku = '900176-001';
DELETE FROM shipping_charge where sku = '9000212-001';
DELETE FROM shipping_charge where sku = '900128-001';
DELETE FROM shipping_charge where sku = '900127-001';
DELETE FROM shipping_charge where sku = '900140-001';
DELETE FROM shipping_charge where sku = '900132-001';
DELETE FROM shipping_charge where sku = '900112-001';
DELETE FROM shipping_charge where sku = '900154-001';
DELETE FROM shipping_charge where sku = '900188-001';
DELETE FROM shipping_charge where sku = '900150-001';
DELETE FROM shipping_charge where sku = '900152-001';
DELETE FROM shipping_charge where sku = '9000214-001';
DELETE FROM shipping_charge where sku = '9000200-001';
DELETE FROM shipping_charge where sku = '900180-001';
DELETE FROM shipping_charge where sku = '900186-001';
DELETE FROM shipping_charge where sku = '900162-001';
DELETE FROM shipping_charge where sku = '900196-001';
DELETE FROM shipping_charge where sku = '900192-001';
DELETE FROM shipping_charge where sku = '900134-001';
DELETE FROM shipping_charge where sku = '900164-001';
DELETE FROM shipping_charge where sku = '900133-001';
DELETE FROM shipping_charge where sku = '900144-001';
DELETE FROM shipping_charge where sku = '900174-001';
DELETE FROM shipping_charge where sku = '900114-001';
DELETE FROM shipping_charge where sku = '900172-001';
DELETE FROM shipping_charge where sku = '9000202-001';


COMMIT;

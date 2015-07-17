-- The following shipping SKUs are being fixed/updated across all our systems
-- because they should have been seperate shipping products and in their current
-- representation they won't fit in the product service.

-- CANDO and MIS have been informed.
BEGIN;

    -- NAP
    UPDATE shipping_charge
    SET sku = '9000211-002'
    WHERE sku = '9000217-001';

    -- OUT
    --UPDATE shipping_charge
    --SET sku = '9000215-002'
    --WHERE sku = '9000221-001';

    -- MRP
    --UPDATE shipping_charge
    --SET sku = '9000213-002'
    --WHERE sku = '9000219-001';

COMMIT;


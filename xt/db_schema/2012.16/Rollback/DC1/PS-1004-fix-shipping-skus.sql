-- The following shipping SKUs are being fixed/updated across all our systems
-- because they should have been seperate shipping products and in their current
-- representation they won't fit in the product service.

-- CANDO and MIS have been informed.
BEGIN;

    -- NAP
    UPDATE shipping_charge
    SET sku = '9000210-002'
    WHERE sku = '9000222-001';

    --OUT
    --UPDATE shipping_charge
    --SET sku = '9000214-002'
    --WHERE sku = '9000220-001';

    -- MRP
    --UPDATE shipping_charge
    --SET sku = '9000212-002'
    --WHERE sku = '9000218-001';

COMMIT;

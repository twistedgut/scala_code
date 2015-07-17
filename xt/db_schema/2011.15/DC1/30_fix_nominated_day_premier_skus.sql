
BEGIN WORK;

-- FLEX-282 - Fix shipping_charge_class for added Premier skus


UPDATE shipping_charge
SET class_id = (SELECT id FROM shipping_charge_class WHERE class = 'Same Day')
WHERE sku IN (
    -- NAP
    '900001-002',
    '900002-002',
    '900005-002',
    -- MRP
    '910001-002',
    '910002-002',
    '910005-002'
);


COMMIT WORK;


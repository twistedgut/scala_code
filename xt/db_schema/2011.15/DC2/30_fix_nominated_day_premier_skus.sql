
BEGIN WORK;

-- FLEX-282 - Fix shipping_charge_class for added Premier skus


UPDATE shipping_charge
SET class_id = (SELECT id FROM shipping_charge_class WHERE class = 'Same Day')
WHERE sku IN (
    -- NAP
    '900025-003',
    -- MRP
    '910025-003'
);



COMMIT WORK;


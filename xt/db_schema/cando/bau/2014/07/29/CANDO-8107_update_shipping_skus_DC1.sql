--
-- For DC1 Only
--

-- CANDO-8107: Update Shipping SKUs on Pre-Orders
--             that have been used that don't exist
--             on the Frontend

BEGIN WORK;

-- update European SKUs
UPDATE  pre_order
    SET shipping_charge_id = (
            SELECT  id
            FROM    shipping_charge
            WHERE   sku = '900008-001'      -- European Express
        )
WHERE   shipping_charge_id IN (
    SELECT  id
    FROM    shipping_charge
    WHERE   sku IN (
        '9000420-008',
        '9000421-008',
        '9000420-002',
        '9000421-002',
        '9000420-003',
        '9000421-003',
        '9000420-004',
        '9000421-004',
        '9000420-005',
        '9000421-005',
        '9000420-006',
        '9000420-006',
        '9000420-007',
        '9000421-007'
    )
)
;

-- update UK SKUs
UPDATE  pre_order
    SET shipping_charge_id = (
            SELECT  id
            FROM    shipping_charge
            WHERE   sku = '900003-001'      -- UK Express
        )
WHERE   shipping_charge_id IN (
    SELECT  id
    FROM    shipping_charge
    WHERE   sku IN (
        '9000420-001'
    )
)
;

COMMIT WORK;

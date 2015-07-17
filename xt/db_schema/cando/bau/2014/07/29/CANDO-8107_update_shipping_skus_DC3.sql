--
-- For DC3 Only
--

-- CANDO-8107: Update Shipping SKUs on Pre-Orders
--             that have been used that don't exist
--             on the Frontend

BEGIN WORK;

-- update Australian SKUs
UPDATE  pre_order
    SET shipping_charge_id = (
            SELECT  id
            FROM    shipping_charge
            WHERE   sku = '9000314-001'     -- Standard 2-4 days Australia
        )
WHERE   shipping_charge_id IN (
    SELECT  id
    FROM    shipping_charge
    WHERE   sku IN (
        '9000325-001'
    )
)
;

COMMIT WORK;

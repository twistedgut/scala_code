-- CANDO-8669: Update the Shipping Option of several Pre-Orders which are
--             using Shipping SKU '9000330-001' to use '9000314-001'
--
-- DC1: No
-- DC2: No
-- DC3: Yes

BEGIN WORK;

-- Create the Pre-Order Note first before updating the Shipping Option.
INSERT INTO pre_order_note ( pre_order_id, note_type_id, operator_id, note )
SELECT  pre.id,
        ( SELECT id FROM pre_order_note_type WHERE description = 'Shipment Address Change' ),
        ( SELECT id FROM operator            WHERE name        = 'Application'             ),
        'BAU (CANDO-8669) to update Shipping Option from ''(9000330-001) Sydney and Melbourne Next Business Day'' to ''(9000314-001) Standard 2-4 days Australia'', so that the Pre-Orders can be converted into Orders.'
FROM    pre_order pre
WHERE   pre.shipping_charge_id = (
    SELECT  id
    FROM    shipping_charge
    WHERE   sku = '9000330-001'
)
AND pre.id NOT IN (
    -- don't update where Orders
    -- have already been created
    SELECT  pre_order_id
    FROM    link_orders__pre_order
)
;

-- Update the Shipping Option.
UPDATE  pre_order
    SET shipping_charge_id = (
        SELECT  id
        FROM    shipping_charge
        WHERE   sku = '9000314-001'
    )
WHERE   shipping_charge_id = (
    SELECT  id
    FROM    shipping_charge
    WHERE   sku = '9000330-001'
)
AND id NOT IN (
    -- don't update where Orders
    -- have already been created
    SELECT  pre_order_id
    FROM    link_orders__pre_order
)
;

COMMIT WORK;

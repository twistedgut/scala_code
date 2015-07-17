
-- FLEX-661
--
-- Mark Regular OUT Shipping Charges to be charged for
--

BEGIN WORK;


UPDATE shipping_charge
    SET is_return_shipment_free = FALSE
    WHERE
        channel_id = (SELECT id FROM channel WHERE name = 'theOutnet.com')
        AND id NOT IN (
            -- Th4ese are still free
            SELECT id FROM shipping_charge WHERE sku IN (
                '9000214-001', -- Premier Daytime
                '9000214-002', -- Premier Evening
                '920011-001',  -- Premier Anytime
                '920015-001',  -- Courier
                '920007-001'   -- Internal Staff Order
            )
        )
;


COMMIT WORK;


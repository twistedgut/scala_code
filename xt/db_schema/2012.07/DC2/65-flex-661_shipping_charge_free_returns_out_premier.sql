
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
            -- These are still free
            SELECT id FROM shipping_charge WHERE sku IN (
                '9000215-001', -- Premier Daytime
                '9000215-002', -- Premier Evening
                '920012-001',  -- Premier Anytime
                '920018-001',  -- Courier
                '920010-001'   -- Internal Staff Order
            )
        )
;


COMMIT WORK;


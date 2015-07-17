
-- FLEX-31
--
-- Add shiping_charge.is_customer_facing, and mark Courier and Premier
-- Anytime as such
--
-- This is e.g. to avoid defaulting to internal Shipping Options while
-- changing address



BEGIN WORK;



ALTER TABLE shipping_charge
    ADD COLUMN is_customer_facing BOOLEAN DEFAULT TRUE NOT NULL;




UPDATE shipping_charge
    SET is_customer_facing = FALSE
    WHERE sku IN (
        -- Courier
        '920016-001',
        '920017-001',
        '920018-001',
        -- Anytime
        '920003-001',
        '920004-001',
        '920012-001',
        -- Staff
        '920008-001',
        '920009-001',
        '920010-001'
    );



COMMIT WORK;

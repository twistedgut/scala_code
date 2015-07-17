
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
        '920013-001',
        '920014-001',
        '920015-001',
        -- Anytime
        '920001-001',
        '920002-001',
        '920011-001',
        -- Staff
        '920005-001',
        '920006-001',
        '920007-001'
    );



COMMIT WORK;

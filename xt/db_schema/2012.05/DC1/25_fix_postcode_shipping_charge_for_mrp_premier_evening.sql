
BEGIN WORK;

-- FLEX-671, fix for FLEX-358
--
-- Fix the postcode_shipping_charge mapping for sku 9000212-002, MRP, Premier Evening



UPDATE postcode_shipping_charge
    SET shipping_charge_id = (
        SELECT id FROM shipping_charge WHERE description LIKE 'Premier Evening' AND channel_id = 5
        )
    WHERE
        shipping_charge_id = (
            SELECT id FROM shipping_charge WHERE description LIKE 'Premier Evening' AND channel_id = 1
        )
        AND channel_id = 5;



COMMIT WORK;



BEGIN;

--
-- FLEX-718 - Rename premier_routing and shipping_charge
--

UPDATE shipping_charge
    SET description = 'FAST TRACK: Premier Anytime'
    WHERE description = 'Premier Anytime'
;


-- Note: 10-17 is the time window the Customer can receive the package.
--
-- The premier_routing.latest_delivery_daytime is still 16:00. This is
-- the latest time the package can be routed, and still reach the
-- customer at 17:00
UPDATE premier_routing
    SET description = 'Daytime, 10:00-17:00'
    WHERE description = 'Daytime, 10:00-16:00'
;


COMMIT;

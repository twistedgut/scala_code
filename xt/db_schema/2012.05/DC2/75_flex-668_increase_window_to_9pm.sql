BEGIN;

-- FLEX-668
-- Increase delivery window from 8pm to 9pm


UPDATE premier_routing
    SET
        latest_delivery_daytime = '21:00'
    WHERE code = 'C' -- Contact Customer
;


UPDATE premier_routing
    SET
         latest_delivery_daytime = '21:00'
        ,description = 'Anytime before 9pm today'
    WHERE code = 'A' -- Any time
;

COMMIT;

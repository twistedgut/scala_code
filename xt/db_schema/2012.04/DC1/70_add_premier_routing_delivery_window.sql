BEGIN;

-- FLEX-250 / FLEX-444
-- Add delivery window columns to the premier_routing table, and
-- default values for them



ALTER TABLE premier_routing
    ADD COLUMN earliest_delivery_daytime TIME WITHOUT TIME ZONE NULL,
    ADD COLUMN latest_delivery_daytime   TIME WITHOUT TIME ZONE NULL
;


UPDATE premier_routing
SET earliest_delivery_daytime = '10:00', latest_delivery_daytime = '20:00';

UPDATE premier_routing
SET earliest_delivery_daytime = '10:00', latest_delivery_daytime = '16:00'
WHERE code = 'B';

UPDATE premier_routing
SET earliest_delivery_daytime = '10:00', latest_delivery_daytime = '16:00'
WHERE code = 'D';

UPDATE premier_routing
SET earliest_delivery_daytime = '18:00', latest_delivery_daytime = '21:00'
WHERE code = 'E';


ALTER TABLE premier_routing
    ALTER COLUMN earliest_delivery_daytime SET NOT NULL,
    ALTER COLUMN latest_delivery_daytime   SET NOT NULL
;


COMMIT;

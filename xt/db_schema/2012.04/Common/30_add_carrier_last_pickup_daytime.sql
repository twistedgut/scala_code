BEGIN;

-- FLEX-286
-- Add a columns to shipment table for project/flex - Nominated Day


ALTER TABLE carrier
    -- The time of day when the delivery van leaves the warehouse for
    -- the last time
    ADD COLUMN last_pickup_daytime TIME NULL
;


UPDATE carrier
SET last_pickup_daytime = '17:00:00'
;


ALTER TABLE carrier
ALTER last_pickup_daytime SET NOT NULL
;


COMMIT;

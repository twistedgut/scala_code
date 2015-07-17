BEGIN;

-- FLEX-287
-- Add a columns to shipment table for project/flex - Nominated Day


ALTER TABLE shipment
    -- The datetime when the shipment needs to be packed so it can be
    -- dispatched from the warehouse
    ADD COLUMN nominated_selection_time TIMESTAMP WITH TIME ZONE NULL
;


COMMIT;


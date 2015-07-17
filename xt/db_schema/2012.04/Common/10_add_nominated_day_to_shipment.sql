BEGIN;

-- FLEX-205
-- Add two columns to shipment table for project/flex - Nominated Day


ALTER TABLE shipment
    -- The nominated date when the customer is supposed to receive the
    -- shipment
    ADD COLUMN nominated_delivery_date DATE NULL,
    -- The datetime when the shipment needs to be packed so it can be
    -- dispatched from the warehouse
    ADD COLUMN nominated_dispatch_time TIMESTAMP WITH TIME ZONE NULL
;


COMMIT;


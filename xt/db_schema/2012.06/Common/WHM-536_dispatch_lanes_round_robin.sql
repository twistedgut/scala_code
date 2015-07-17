-- Create tables to manage available and last used dispatch lanes per shipment type

BEGIN;

    -- Create table with available lanes per shipment type
    -- Each shipment type should have one or more lanes
    CREATE TABLE dispatch_lane (
        id SERIAL PRIMARY KEY,
        shipment_type_id INTEGER REFERENCES public.shipment_type NOT NULL,
        lane_nr INTEGER NOT NULL
    );
    ALTER TABLE dispatch_lane OWNER TO www;
    CREATE UNIQUE INDEX ix_dispatch_lane_shipment_type_id ON dispatch_lane(shipment_type_id, lane_nr);

    -- Create table to store the offset for dispatch_lane per shipment_type
    -- This tracks the last used index in the available lanes for each shipment type
    CREATE TABLE dispatch_lane_offset (
        shipment_type_id INTEGER REFERENCES public.shipment_type NOT NULL PRIMARY KEY,
        lane_offset INTEGER NOT NULL DEFAULT 0
    );
    ALTER TABLE dispatch_lane_offset OWNER TO www;

COMMIT;

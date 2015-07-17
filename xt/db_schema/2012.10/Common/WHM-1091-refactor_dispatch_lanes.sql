-- WHM-1091 - shipment_type<->dispatch_lane should be many-to-many

-- Before this patch, dispatch lanes are implicit objects - they exist only
-- when joined to a shipment type, and the lane_nr is what combines those
-- rows into a lane. Now that the config is being made interactive, it's
-- possible to stop any shipment_type from using a particular lane. This
-- would cause it to be removed from the database, meaning it can't be
-- fixed in the config interface again. :) Making this a proper many-to-many
-- is the answer, and this patch combines all those rows into real objects
-- and sets up the joins to the shipment types to match the current config.

BEGIN WORK;

    -- Create link table
    CREATE TABLE link_shipment_type__dispatch_lane (
        shipment_type_id INTEGER NOT NULL REFERENCES shipment_type(id),
        dispatch_lane_id INTEGER NOT NULL REFERENCES dispatch_lane(id)
    );
    ALTER TABLE link_shipment_type__dispatch_lane OWNER TO www;

    -- Create join rows
    INSERT INTO link_shipment_type__dispatch_lane (shipment_type_id, dispatch_lane_id)
        SELECT DISTINCT ON (dl.shipment_type_id, dl.lane_nr) dl.shipment_type_id, MIN(dl2.id)
        FROM dispatch_lane dl
        JOIN dispatch_lane dl2
        USING (lane_nr)
        GROUP BY dl.shipment_type_id, dl.lane_nr
        ORDER BY dl.shipment_type_id, dl.lane_nr;

    -- De-dupe dispatch lane rows
    DELETE FROM dispatch_lane dl
        WHERE dl.id IN (
            SELECT dl.id
            FROM dispatch_lane dl
            LEFT JOIN link_shipment_type__dispatch_lane lstdl
                ON dl.id = lstdl.dispatch_lane_id
            WHERE lstdl.shipment_type_id IS NULL
        );

    -- Remove shipment type from dispatch lane
    ALTER TABLE dispatch_lane
        DROP COLUMN shipment_type_id;

    -- Ensure lane_nr is unique in dispatch_lane
    CREATE UNIQUE INDEX dispatch_lane_lane_nr_unique ON dispatch_lane(lane_nr);

COMMIT;

-- Populate the dispatch lane tables with DC1 configuration

BEGIN;

    -- DC1 has 5 dispatch lanes
    INSERT INTO dispatch_lane (shipment_type_id, lane_nr )
        VALUES
            (1,1), (1,2), (1,3),    -- unknown              -> lanes 1,2,3
            (2,5),                  -- premier              -> lane 5
            (3,4),                  -- domestic             -> lane 4
            (4,1), (4,2), (4,3),    -- international        -> lanes 1,2,3
            (5,1), (5,2), (5,3);    -- international ddu    -> lanes 1,2,3

    -- reset lane counter for each shipment type
    INSERT INTO dispatch_lane_offset (shipment_type_id, lane_offset )
        VALUES (1,0), (2,0), (3,0), (4,0), (5,0);

COMMIT;

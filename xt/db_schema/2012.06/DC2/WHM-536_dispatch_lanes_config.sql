-- Populate the dispatch lane tables with DC2 configuration

BEGIN;

    -- DC2 effectively has 1 dispatch lane as they don't use round robin at this point
    INSERT INTO dispatch_lane (shipment_type_id, lane_nr )
        VALUES
            (1,1),                  -- unknown              -> lane 1
            (2,1),                  -- premier              -> lane 1
            (3,1),                  -- domestic             -> lane 1
            (4,1),                  -- international        -> lane 1
            (5,1);                  -- international ddu    -> lane 1

    -- reset lane counter for each shipment type
    INSERT INTO dispatch_lane_offset (shipment_type_id, lane_offset )
        VALUES (1,0), (2,0), (3,0), (4,0), (5,0);

COMMIT;

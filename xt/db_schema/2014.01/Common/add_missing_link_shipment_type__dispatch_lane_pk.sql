-- Add a missing PK to the table

BEGIN;
    ALTER TABLE link_shipment_type__dispatch_lane
        ADD PRIMARY KEY (shipment_type_id, dispatch_lane_id)
    ;
COMMIT;

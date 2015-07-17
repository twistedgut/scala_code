-- Add an index to return_arrival(return_delivery_id) to speed up
-- get_returns_arrived

BEGIN;
    CREATE INDEX return_arrival_return_delivery_id_idx ON return_arrival(return_delivery_id);
COMMIT;

-- Add an RTO (Return To Origin) boolean field to the return_arrival table
-- and a field for the number of packages with the same AWB

BEGIN;

ALTER TABLE return_arrival ADD COLUMN rto boolean NOT NULL DEFAULT FALSE;
ALTER TABLE return_arrival ADD COLUMN packages integer NOT NULL DEFAULT 1;

COMMIT;

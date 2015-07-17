-- DCA-591: Make putaway_prep_container's destination column
-- a foreign key to the location table's location column

BEGIN;

-- remove all rows so that they won't break the new constraint
TRUNCATE putaway_prep_container CASCADE;

-- add foreign key
ALTER TABLE putaway_prep_container
    ADD CONSTRAINT putaway_prep_destination_fkey FOREIGN KEY (destination)
    REFERENCES location (location) DEFERRABLE;

COMMIT;

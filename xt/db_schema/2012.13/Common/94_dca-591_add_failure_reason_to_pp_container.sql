-- DCA-591: Add failure_reason column to putaway_prep_container

BEGIN;

ALTER TABLE putaway_prep_container ADD COLUMN failure_reason VARCHAR(255) NULL;

COMMIT;

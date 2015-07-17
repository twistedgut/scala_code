-- DCA-45: rename status_id to putaway_prep_status_id and make it deferrable

BEGIN;

ALTER TABLE putaway_prep RENAME COLUMN status_id TO putaway_prep_status_id;

ALTER TABLE putaway_prep DROP CONSTRAINT putaway_prep_status_id_fkey;
ALTER TABLE putaway_prep ADD CONSTRAINT putaway_prep_status_id_fkey FOREIGN KEY (putaway_prep_status_id) REFERENCES putaway_prep_status(id) DEFERRABLE;

COMMIT;

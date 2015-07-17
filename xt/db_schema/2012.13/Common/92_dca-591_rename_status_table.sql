-- DCA-591: rename putaway_prep_status table
--          because it's actually putaway prep container status

BEGIN;

ALTER TABLE putaway_prep_status RENAME TO putaway_prep_container_status;

-- Fix up the sequence
ALTER SEQUENCE putaway_prep_status_id_seq RENAME TO putaway_prep_container_status_id_seq;
SELECT setval('putaway_prep_container_status_id_seq',(SELECT max(id) FROM putaway_prep_container_status)+1);

COMMIT;

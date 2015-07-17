-- DCA-46: Add 'Resolved' status

BEGIN;

-- Nastiness as the putaway_prep_container_status sequence
-- seems broken. TODO: Investigate further.

SELECT setval('putaway_prep_container_status_id_seq',
              (SELECT max(id) FROM putaway_prep_container_status) + 1);

INSERT INTO putaway_prep_container_status (status, description) VALUES
    ('Resolved', 'Putaway Prep container problem has been resolved');

COMMIT;

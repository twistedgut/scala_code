-- DCA-591: Add 'In Transit' status

BEGIN;

INSERT INTO putaway_prep_container_status (status, description) VALUES
    ('In Transit', 'Putaway Prep container Advice has been sent');

COMMIT;

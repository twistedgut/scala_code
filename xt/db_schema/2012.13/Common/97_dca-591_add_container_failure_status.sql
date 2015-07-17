-- DCA-591: Add 'failure' status for putaway_prep_container

BEGIN;

INSERT INTO putaway_prep_container_status (status, description)
    VALUES ('Failure', 'AdviceResponse message indicates failure');

UPDATE putaway_prep_container_status
    SET description = 'AdviceResponse message indicates success'
    WHERE status = 'Complete';

COMMIT;

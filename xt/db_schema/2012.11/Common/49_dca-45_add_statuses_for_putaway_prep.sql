-- DCA-45: Set possible statuses for Putaway Prep

BEGIN;

INSERT INTO putaway_prep_status (status) VALUES ('In Progress');
INSERT INTO putaway_prep_status (status) VALUES ('Complete');

COMMIT;

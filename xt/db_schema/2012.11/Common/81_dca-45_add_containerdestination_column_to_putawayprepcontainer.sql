-- DCA-45: Add extra column to "putaway_prep_container" that is going to
-- store PRL where container is being sent. This field is populated
-- after "advice" message is sent.

BEGIN;

ALTER TABLE putaway_prep_container ADD COLUMN destination varchar(50);

COMMIT;

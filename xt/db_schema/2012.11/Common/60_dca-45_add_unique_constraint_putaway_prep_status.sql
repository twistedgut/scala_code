-- DCA-45: Make putaway_prep_status.status column unique, and add a description field

BEGIN;

CREATE UNIQUE INDEX putaway_prep_status_key ON putaway_prep_status (status);

ALTER TABLE putaway_prep_status ADD COLUMN description VARCHAR(255) DEFAULT 'FIXME';

UPDATE putaway_prep_status SET description = 'Putaway Preparation is in progress' WHERE status = 'In Progress';
UPDATE putaway_prep_status SET description = 'Putaway Preparation has been completed' WHERE status = 'Complete';

ALTER TABLE putaway_prep_status ALTER COLUMN description DROP DEFAULT;
ALTER TABLE putaway_prep_status ALTER COLUMN description SET NOT NULL;

COMMIT;

-- CANDO-2682: Add a column to the fraud rules tables to store multiple tags.

BEGIN WORK;

ALTER TABLE fraud.live_rule
    ADD COLUMN tag_list TEXT;

ALTER TABLE fraud.staging_rule
    ADD COLUMN tag_list TEXT;

ALTER TABLE fraud.archived_rule
    ADD COLUMN tag_list TEXT;

COMMIT;


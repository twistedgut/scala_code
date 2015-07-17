BEGIN;

ALTER TABLE location DROP COLUMN channel_id;

COMMIT;

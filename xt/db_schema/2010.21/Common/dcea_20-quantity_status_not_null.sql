--  make status not null on quantity table
BEGIN;

    ALTER TABLE quantity ALTER COLUMN status_id SET NOT NULL;

COMMIT;

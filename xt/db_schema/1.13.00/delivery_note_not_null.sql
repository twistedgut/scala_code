-- Make delivery_id field not null

BEGIN;

    ALTER TABLE delivery_note ALTER COLUMN delivery_id SET NOT NULL;

COMMIT;

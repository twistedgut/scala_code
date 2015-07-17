-- Add a column to delivery to put it on hold

BEGIN;

ALTER TABLE delivery ADD COLUMN on_hold boolean DEFAULT FALSE NOT NULL;

COMMIT;

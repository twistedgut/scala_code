-- Add held/released to delivery_log
-- Set delivery_note fields to not null and set default value of modified
-- to current_timestamp

BEGIN;

    INSERT INTO delivery_action ( action ) VALUES ( 'Held' );
    INSERT INTO delivery_action ( action ) VALUES ( 'Released' );

    ALTER TABLE delivery_note ALTER COLUMN created SET DEFAULT CURRENT_TIMESTAMP;
    ALTER TABLE delivery_note ALTER COLUMN modified SET DEFAULT CURRENT_TIMESTAMP;
    UPDATE delivery_note SET modified = CURRENT_TIMESTAMP WHERE modified IS NULL;
    UPDATE delivery_note SET modified_by = created_by WHERE modified_by IS NULL;
    ALTER TABLE delivery_note ALTER COLUMN modified_by SET NOT NULL;
    ALTER TABLE delivery_note ALTER COLUMN modified SET NOT NULL;

COMMIT;

BEGIN;
    ALTER TABLE delivery_item ALTER COLUMN delivery_id SET NOT NULL;
    ALTER TABLE delivery_item ALTER COLUMN status_id SET NOT NULL;
    ALTER TABLE delivery_item ALTER COLUMN type_id SET NOT NULL;
COMMIT;

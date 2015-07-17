BEGIN;
    ALTER TABLE packaging_type DROP COLUMN channel_id;
    ALTER TABLE packaging_type ADD PRIMARY KEY (id);
COMMIT;

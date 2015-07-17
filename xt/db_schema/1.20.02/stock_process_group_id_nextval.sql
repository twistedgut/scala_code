-- Link group_id to process_group_id

BEGIN;
    ALTER TABLE stock_process
        ALTER COLUMN group_id
            SET DEFAULT nextval('process_group_id_seq'::regclass);

    ALTER TABLE stock_process
        ALTER COLUMN group_id
            SET NOT NULL;

COMMIT;

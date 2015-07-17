-- Change the primary key for the log_location table

BEGIN;
    ALTER TABLE log_location
        DROP CONSTRAINT log_new_location_pkey,
        ADD COLUMN id serial PRIMARY KEY;
    ALTER TABLE log_location OWNER TO www;
    DROP INDEX new_log_location_variant_id_key;
    CREATE INDEX ix_log_location_variant_id ON log_location(variant_id);
    CREATE INDEX ix_log_location_location_id ON log_location(location_id);
    CREATE INDEX ix_log_location_channel_id ON log_location(channel_id);
COMMIT;

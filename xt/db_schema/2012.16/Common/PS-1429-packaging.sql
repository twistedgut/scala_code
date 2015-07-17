-- We add a new table to hold descriptive packaging information for use by
-- customer clients via the product service.
-- See the ticket in JIRA for more information.
BEGIN;

    -- Add unique constraint to the original table
    -- We should never have duplicate SKUs
    ALTER TABLE packaging_type ADD UNIQUE (sku);

    -- Create the new table
    CREATE TABLE packaging_attribute (
        id SERIAL PRIMARY KEY,
        packaging_type_id INTEGER REFERENCES packaging_type(id) DEFERRABLE,
        name TEXT NOT NULL,
        public_name TEXT NOT NULL,
        title TEXT NOT NULL,
        public_title TEXT NOT NULL,
        channel_id INTEGER REFERENCES channel(id) DEFERRABLE,
        description TEXT NOT NULL,
        UNIQUE (packaging_type_id, channel_id)
    );

    GRANT ALL ON packaging_attribute TO www;
    GRANT ALL ON packaging_attribute TO postgres;
    GRANT ALL ON packaging_attribute_id_seq TO www;
    GRANT ALL ON packaging_attribute_id_seq TO postgres;
    GRANT ALL ON packaging_type_id_seq TO postgres;
    GRANT ALL ON packaging_type_id_seq TO www;
COMMIT;

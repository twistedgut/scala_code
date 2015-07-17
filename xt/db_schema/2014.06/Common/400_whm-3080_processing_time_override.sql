-- WHM-3080: Create new 'processing_time_precedence' table
--    which filters processing_time rows depending on business rules for which
--    attributes override which others.

BEGIN;

    CREATE TABLE sos.processing_time_override (
        id SERIAL PRIMARY KEY,
        major_id INTEGER REFERENCES sos.processing_time(id) DEFERRABLE,
        minor_id INTEGER REFERENCES sos.processing_time(id) DEFERRABLE
    );

    -- create indexes on foreign keys
    CREATE INDEX processing_time_override_major_id ON sos.processing_time_override (major_id);
    CREATE INDEX processing_time_override_minor_id ON sos.processing_time_override (minor_id);

    ALTER TABLE sos.processing_time_override OWNER TO www;

COMMIT;

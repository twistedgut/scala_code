-- LSR-2: Remove Obsolete Tables

BEGIN WORK;

    -- Create a schema to temporarily hold tables that are marked for
    -- deletion. Once they have been here for an iteration without problems
    -- they can be dropped for good
    CREATE SCHEMA obsolete;
    ALTER SCHEMA obsolete OWNER TO www;

COMMIT;
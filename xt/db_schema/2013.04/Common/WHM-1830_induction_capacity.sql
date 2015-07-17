-- Add a runtime_property table and the induction_capacity key

BEGIN;
    CREATE TABLE runtime_property (
        id SERIAL PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        description TEXT NOT NULL
    );
    ALTER TABLE runtime_property OWNER TO www;
    COMMENT ON TABLE runtime_property IS 'This table is used to store non-user defined runtime properties of the system';

    INSERT INTO runtime_property (name, value, description) VALUES (
        'induction_capacity',
        '0',
        'This is an integer that provides operators with a count of how many cached allocation containers can be placed on the pack lane'
    );
COMMIT;

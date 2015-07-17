-- WHM-883 Add tables for system parameters and their groups

BEGIN WORK;

    -- Each parameter group has a name and a description and a flag indicating
    -- whether or not it should be visible in the system parameters interface.
    CREATE TABLE system_config.parameter_group (
        id SERIAL NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        visible BOOLEAN NOT NULL DEFAULT FALSE,
        PRIMARY KEY (id),
        UNIQUE (name)
    );
    ALTER TABLE system_config.parameter_group OWNER TO www;

    -- Create available parameter types
    CREATE TABLE system_config.parameter_type (
        id SERIAL NOT NULL,
        type CHARACTER VARYING(255) NOT NULL,
        PRIMARY KEY (id),
        UNIQUE (type)
    );
    ALTER TABLE system_config.parameter_type OWNER TO www;

    -- Add known parameter types
    INSERT INTO system_config.parameter_type (type) VALUES
        ( 'boolean' ),
        ( 'integer' ),
        ( 'string' );

    -- Each parameter has a name, a description, a type and a value. The type
    -- is used for validation and interface generation.
    CREATE TABLE system_config.parameter (
        id SERIAL NOT NULL,
        parameter_group_id INTEGER NOT NULL REFERENCES system_config.parameter_group(id),
        parameter_type_id INTEGER NOT NULL REFERENCES system_config.parameter_type(id),
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (id),
        UNIQUE (parameter_group_id, name)
    );
    ALTER TABLE system_config.parameter OWNER TO www;

COMMIT;

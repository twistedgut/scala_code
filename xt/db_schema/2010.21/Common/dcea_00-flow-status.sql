-- Create flow schema for status engine
BEGIN;

    CREATE SCHEMA flow;
    ALTER SCHEMA flow OWNER TO www;

    CREATE TABLE flow.type (
        id serial PRIMARY KEY,
        name text NOT NULL UNIQUE
    );
    ALTER TABLE flow.type OWNER TO www;


    CREATE TABLE flow.status (
        id serial PRIMARY KEY,
        name text NOT NULL,
        type_id integer REFERENCES flow.type(id) DEFERRABLE NOT NULL,
        is_initial boolean not null default false,
        UNIQUE( name, type_id )
    );
    ALTER TABLE flow.status OWNER TO www;

    CREATE TABLE flow.next_status (
        current_status_id integer REFERENCES flow.status(id) DEFERRABLE NOT NULL,
        next_status_id integer REFERENCES flow.status(id) DEFERRABLE NOT NULL
    );
    ALTER TABLE flow.next_status ADD PRIMARY KEY (current_status_id, next_status_id);
    ALTER TABLE flow.next_status OWNER TO www;

COMMIT;

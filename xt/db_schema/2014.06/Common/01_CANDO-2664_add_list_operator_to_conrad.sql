-- CANDO-2664: Add functionality to CONRAD that implements lists as an operator type.

BEGIN WORK;


-- Create a table to store the different types of lists.

CREATE TABLE fraud.list_type (
    id      SERIAL NOT NULL PRIMARY KEY,
    type    VARCHAR(50)
);

ALTER TABLE fraud.list_type OWNER TO postgres;
GRANT ALL ON TABLE fraud.list_type TO www;
GRANT ALL ON SEQUENCE fraud.list_type_id_seq TO www;

INSERT INTO fraud.list_type (
    type
) VALUES
    ( 'Customer Category' ),
    ( 'Customer Class' ),
    ( 'Shipment Type' ),
    ( 'Country' )
;


-- Add a column to match a method to a list type.

ALTER TABLE fraud.method
    ADD COLUMN
        list_type_id INTEGER REFERENCES fraud.list_type(id);

UPDATE fraud.method
    SET     list_type_id = ( SELECT id FROM fraud.list_type WHERE type = 'Customer Category' )
    WHERE   description = 'Customer Category';

UPDATE fraud.method
    SET list_type_id = ( SELECT id FROM fraud.list_type WHERE type = 'Customer Class' )
    WHERE description = 'Customer Class';

UPDATE fraud.method
    SET list_type_id = ( SELECT id FROM fraud.list_type WHERE type = 'Shipment Type' )
    WHERE description = 'Shipment Type';

UPDATE fraud.method
    SET list_type_id = ( SELECT id FROM fraud.list_type WHERE type = 'Country' )
    WHERE description = 'Shipping Address Country';


-- Create 'versioned' tables to store each list.

CREATE TABLE fraud.archived_list (
    id                      SERIAL NOT NULL PRIMARY KEY,
    list_type_id            INTEGER REFERENCES fraud.list_type(id),
    name                    VARCHAR(50) NOT NULL,
    description             VARCHAR(255) NOT NULL,
    change_log_id           INTEGER NOT NULL REFERENCES fraud.change_log(id),
    created                 TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_by_operator_id  INTEGER NOT NULL REFERENCES operator(id),
    expired                 TIMESTAMP WITH TIME ZONE,
    expired_by_operator_id  INTEGER REFERENCES operator(id)
);

ALTER TABLE fraud.archived_list OWNER TO postgres;
GRANT ALL ON TABLE fraud.archived_list TO www;
GRANT ALL ON SEQUENCE fraud.archived_list_id_seq TO www;

CREATE TABLE fraud.live_list (
    id              SERIAL NOT NULL PRIMARY KEY,
    list_type_id    INTEGER REFERENCES fraud.list_type(id),
    name            VARCHAR(50) NOT NULL UNIQUE,
    description     VARCHAR(255) NOT NULL,
    archived_list_id INTEGER NOT NULL REFERENCES fraud.archived_list(id)
);

ALTER TABLE fraud.live_list OWNER TO postgres;
GRANT ALL ON TABLE fraud.live_list TO www;
GRANT ALL ON SEQUENCE fraud.live_list_id_seq TO www;

CREATE TABLE fraud.staging_list (
    id              SERIAL NOT NULL PRIMARY KEY,
    list_type_id    INTEGER REFERENCES fraud.list_type(id),
    name            VARCHAR(50) NOT NULL UNIQUE,
    description     VARCHAR(255) NOT NULL,
    live_list_id    INTEGER REFERENCES fraud.live_list(id)
);

ALTER TABLE fraud.staging_list OWNER TO postgres;
GRANT ALL ON TABLE fraud.staging_list TO www;
GRANT ALL ON SEQUENCE fraud.staging_list_id_seq TO www;


-- Create 'versioned' tables to store all the items in each list.

CREATE TABLE fraud.live_list_item (
    id          SERIAL NOT NULL PRIMARY KEY,
    list_id     INTEGER NOT NULL REFERENCES fraud.live_list(id),
    value       VARCHAR(255) NOT NULL
);

ALTER TABLE fraud.live_list_item OWNER TO postgres;
GRANT ALL ON TABLE fraud.live_list_item TO www;
GRANT ALL ON SEQUENCE fraud.live_list_item_id_seq TO www;

CREATE TABLE fraud.staging_list_item (
    id          SERIAL NOT NULL PRIMARY KEY,
    list_id     INTEGER NOT NULL REFERENCES fraud.staging_list(id),
    value       VARCHAR(255) NOT NULL
);

ALTER TABLE fraud.staging_list_item OWNER TO postgres;
GRANT ALL ON TABLE fraud.staging_list_item TO www;
GRANT ALL ON SEQUENCE fraud.staging_list_item_id_seq TO www;

CREATE TABLE fraud.archived_list_item (
    id          SERIAL NOT NULL PRIMARY KEY,
    list_id     INTEGER NOT NULL REFERENCES fraud.archived_list(id),
    value       VARCHAR(255) NOT NULL
);

ALTER TABLE fraud.archived_list_item OWNER TO postgres;
GRANT ALL ON TABLE fraud.archived_list_item TO www;
GRANT ALL ON SEQUENCE fraud.archived_list_item_id_seq TO www;

-- Add a column to determine if a conditional operator supports lists or not.

ALTER TABLE fraud.conditional_operator
    ADD COLUMN
        is_list_operator BOOLEAN NOT NULL DEFAULT FALSE;

-- Insert List operators into conditional operator table

INSERT INTO fraud.conditional_operator (
    description, symbol, perl_operator, is_list_operator
)
VALUES
    ('Is In List', 'In', 'grep', true),
    ('Not In List', 'Not In', '!grep', true)
;

-- Create the link between the 'dbid' return type and the new list operators.

INSERT INTO fraud.link_return_value_type__conditional_operator (
    return_value_type_id,
    conditional_operator_id
) VALUES
    ( ( SELECT id FROM fraud.return_value_type WHERE type = 'dbid' ), ( SELECT id FROM fraud.conditional_operator WHERE description = 'Is In List' ) ),
    ( ( SELECT id FROM fraud.return_value_type WHERE type = 'dbid' ), ( SELECT id FROM fraud.conditional_operator WHERE description = 'Not In List' ) ),
    ( ( SELECT id FROM fraud.return_value_type WHERE type = 'string' ), ( SELECT id FROM fraud.conditional_operator WHERE description = 'Is In List' ) ),
    ( ( SELECT id FROM fraud.return_value_type WHERE type = 'string' ), ( SELECT id FROM fraud.conditional_operator WHERE description = 'Not In List' ) )
;

COMMIT;


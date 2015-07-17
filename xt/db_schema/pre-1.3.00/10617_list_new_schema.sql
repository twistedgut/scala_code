-- after a long meeting on the morning of 2007-07-31
-- this is the latest attempt at the schema for listy-stuff in xtracker

BEGIN;

------------------------------------------------------------------------------
-- THE GENERALISED LIST NAMESPACE
------------------------------------------------------------------------------

-- new namespace/schema
CREATE SCHEMA list;
GRANT ALL ON SCHEMA list TO www;


-- lists have types
CREATE TABLE list.type (
    id                  serial          primary key,
    name                varchar(255)    not null,

    UNIQUE(name)
);
-- make sure www can use the table
GRANT ALL ON list.type TO www;
GRANT ALL ON list.type_id_seq TO www;
-- we should define some list types to get the ball rolling
INSERT INTO list.type (id, name) VALUES (default, 'Photography');
INSERT INTO list.type (id, name) VALUES (default, 'Pre-Shoot');
INSERT INTO list.type (id, name) VALUES (default, 'Upload');
INSERT INTO list.type (id, name) VALUES (default, 'Upload Watch');
INSERT INTO list.type (id, name) VALUES (default, 'Editorial');
INSERT INTO list.type (id, name) VALUES (default, 'Fit Notes');

-- lists have a status
CREATE TABLE list.status (
    id                  serial          primary key,
    name                varchar(255)    not null,

    UNIQUE(name)
);
-- make sure www can use the table
GRANT ALL ON list.status TO www;
GRANT ALL ON list.status_id_seq TO www;
-- start with at least one status (UNDEFINED) to get the ball rolling
-- using id=0 means we don't affect the PKs sequence
INSERT INTO list.status (id, name) VALUES (0,         'Undefined');
INSERT INTO list.status (id, name) VALUES (default,   'New');
INSERT INTO list.status (id, name) VALUES (default,   'Working');
INSERT INTO list.status (id, name) VALUES (default,   'Empty');
INSERT INTO list.status (id, name) VALUES (default,   'In Progress');
INSERT INTO list.status (id, name) VALUES (default,   'Ready');
INSERT INTO list.status (id, name) VALUES (default,   'Complete');



-- top-level generic "list" table
CREATE TABLE list.list (
    id                  SERIAL PRIMARY KEY,
    name                VARCHAR(255)    NOT NULL,
    type_id             INTEGER         NOT NULL
                        REFERENCES list.type(id),
    status_id           INTEGER         NOT NULL
                        REFERENCES list.status(id)
                        DEFAULT 0,

    created             TIMESTAMP WITH TIME ZONE
                        NOT NULL
                        DEFAULT CURRENT_TIMESTAMP,
    last_modified       TIMESTAMP WITH TIME ZONE
                        NOT NULL
                        DEFAULT CURRENT_TIMESTAMP,

    created_by          INTEGER         NOT NULL
                        REFERENCES operator(id),
    last_modified_by    INTEGER         NOT NULL
                        REFERENCES operator(id),
    due                 DATE
);
-- make sure www can use the table
GRANT ALL ON list.list TO www;
GRANT ALL ON list.list_id_seq TO www;



-- Additional tables for handling of states on items. Since the items progress
-- a work flow that changes state. People of different levels ie operator or
-- manager will have potentially different options on changing the state of an
-- item. This is not used.. YET
-- Jason Tang

-- items have states
CREATE TABLE list.item_state (
    id          SERIAL PRIMARY KEY,
    type_id     INTEGER NOT NULL DEFAULT 0 REFERENCES list.type(id),
    name        TEXT NOT NULL,
    display_id  integer references display.list_itemstate(id),
    UNIQUE (type_id,name)
);

GRANT ALL ON list.item_state TO www;
GRANT ALL ON list.item_state_id_seq TO www;

-- Editorial States
INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Editorial'), 'New');

INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Editorial'), 'In Progress');

INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Editorial'), 'Awaiting Approval');

INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Editorial'), 'Approved');

INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Editorial'), 'Rejected');

-- Photography States
INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Photography'), 'New');

INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Photography'), 'In Progress');

INSERT INTO list.item_state (type_id, name, display_id) VALUES
(
    (SELECT id FROM list.type WHERE name = 'Photography'),
    'Awaiting Approval',
    (SELECT id FROM display.list_itemstate WHERE comment='Photography Awaiting Approval')
);

INSERT INTO list.item_state (type_id, name, display_id) VALUES
(
    (SELECT id FROM list.type WHERE name = 'Photography'),
    'Approved',
    (SELECT id FROM display.list_itemstate WHERE comment='Photography Approved')
);

INSERT INTO list.item_state (type_id, name, display_id) VALUES
(
    (SELECT id FROM list.type WHERE name = 'Photography'),
    'Final Approval',
    (SELECT id FROM display.list_itemstate WHERE comment='Photography Final Approval')
);

INSERT INTO list.item_state (type_id, name, display_id) VALUES
(
    (SELECT id FROM list.type WHERE name = 'Photography'),
    'Rejected',
    (SELECT id FROM display.list_itemstate WHERE comment='Photography Rejected')
);

-- upload item states - currently wont be used but to keep db integrity
INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Upload'), 'Added');


-- Product Advisers
INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Fit Notes'), 'New');

INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Fit Notes'), 'In Progress');

INSERT INTO list.item_state (type_id, name) VALUES
((SELECT id FROM list.type WHERE name = 'Fit Notes'), 'Complete');


-- lists have items
CREATE TABLE list.item (
    id                  serial          primary key,
    list_id             integer         not null
                        references list.list(id),
    created             timestamp with time zone
                        not null
                        default CURRENT_TIMESTAMP,
    last_modified       timestamp with time zone
                        not null
                        default CURRENT_TIMESTAMP,
    type_id             INTEGER         NOT NULL
                        REFERENCES list.type(id),

    created_by          integer         not null
                        references operator(id),
    last_modified_by    integer         not null
                        references operator(id),
    item_state_id       INTEGER NOT NULL REFERENCES list.item_state(id)
);
-- make sure www can use the table
GRANT ALL ON list.item TO www;
GRANT ALL ON list.item_id_seq TO www;


CREATE TABLE list.comment (
    id                  SERIAL PRIMARY KEY,
    list_id             INTEGER NOT NULL REFERENCES list.list(id),
    content             TEXT,    
    created             TIMESTAMP WITH TIME ZONE NOT NULL
                        DEFAULT CURRENT_TIMESTAMP,
    created_by          INTEGER NOT NULL
                        REFERENCES operator(id)
);
GRANT ALL ON list.comment TO www;
GRANT ALL ON list.comment_id_seq TO www;


CREATE TABLE list.child (
    id                  SERIAL PRIMARY KEY,
    parent_id           INTEGER NOT NULL REFERENCES list.list(id),
    child_id            INTEGER NOT NULL REFERENCES list.list(id),
    UNIQUE (parent_id, child_id)
);
GRANT ALL ON list.child TO www;
GRANT ALL ON list.child_id_seq TO www;


-- potential to extend this to become a state machine/manager too
-- CREATE TABLE list.next_state (
--     id              SERIAL PRIMARY KEY,
--     name            TEXT,
--     curr_state_id   INTEGER REFERENCES list.item_state(id),
--     next_state_id   INTEGER REFERENCES list.item_state(id),
--     type_id         INTEGER REFERENCES list.type(id)
-- );
-- GRANT ALL ON list.next_state TO www;
-- GRANT ALL ON list.next_state_id_seq TO www;



\dp list.*

COMMIT;

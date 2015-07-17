-- Purpose:
--  Create/Amend TABLEs for worklist stuff

BEGIN;

-- CREATE new worklist SCHEMA
CREATE SCHEMA worklist;
GRANT ALL ON SCHEMA worklist TO www;


-- CREATE worklist type TABLE
CREATE TABLE worklist.type (
    id              serial primary key, 
    type            varchar(255) NOT NULL
);

-- CREATE due table
CREATE TABLE worklist.due (
    id              serial primary key,
    due_on          date
);

GRANT ALL ON worklist.type to www;
GRANT ALL ON worklist.type_id_seq to www;

INSERT INTO worklist.type (id, type) VALUES (default, 'Upload');
INSERT INTO worklist.type (id, type) VALUES (default, 'Upload Watch');
INSERT INTO worklist.type (id, type) VALUES (default, 'Pre-Shoot');


-- CREATE worklist TABLE
CREATE TABLE worklist.list (
    id              serial primary key, 
    name            varchar(255) NOT NULL,
    type_id         integer references worklist.type(id) not null,
    created         timestamp with time zone
                    NOT NULL
                    default CURRENT_TIMESTAMP,
    last_modified   timestamp with time zone
                    NOT NULL
                    default CURRENT_TIMESTAMP,
    created_by      integer references operator(id) not null,
    last_updated_by integer references operator(id) not null
);

GRANT ALL ON worklist.list to www;
GRANT ALL ON worklist.list_id_seq to www;


-- CREATE link TABLE between worklist and product
CREATE TABLE worklist.list__product (
    id              serial primary key, 
    list_id         integer references worklist.list(id) not null,
    product_id      integer references product(id) not null,
    due_id          integer references worklist.due(id),
    created         timestamp with time zone
                    NOT NULL
                    default CURRENT_TIMESTAMP,
    last_modified   timestamp with time zone
                    NOT NULL
                    default CURRENT_TIMESTAMP,
    created_by      integer references operator(id) not null,

    -- product can only be in a list once
    UNIQUE (list_id, product_id)
);

GRANT ALL ON worklist.list__product to www;
GRANT ALL ON worklist.list__product_id_seq to www;


-- CREATE upload data TABLE
CREATE TABLE upload_data (
    id              serial primary key,
    name            varchar(255) NOT NULL,
    upload_date     timestamp with time zone
                    NOT NULL,
    target_value    numeric(10,2) NOT NULL,
    status_id       integer references upload_status(id) not null,
    created         timestamp with time zone
                    NOT NULL
                    default CURRENT_TIMESTAMP,
    last_modified   timestamp with time zone
                    NOT NULL
                    default CURRENT_TIMESTAMP
);

GRANT ALL ON upload_data to www;
GRANT ALL ON upload_data_id_seq to www;


-- CREATE link TABLE between worklist and upload data
CREATE TABLE worklist.list__upload_data (
    id              serial primary key, 
    list_id         integer references worklist.list(id) not null,
    upload_data_id  integer references upload_data(id) not null,

    -- list can only be linked to an upload once
    UNIQUE (list_id, upload_data_id)
);

GRANT ALL ON worklist.list__upload_data to www;
GRANT ALL ON worklist.list__upload_data_id_seq to www;

-- attach the last_modified update trigger to the TABLE(s)
CREATE TRIGGER update_worklistlist_last_modified BEFORE UPDATE
    ON worklist.list
        FOR EACH ROW EXECUTE PROCEDURE update_last_modified_time();

CREATE TRIGGER update_worklistproduct_last_modified BEFORE UPDATE
    ON worklist.list__product
        FOR EACH ROW EXECUTE PROCEDURE update_last_modified_time();

CREATE TRIGGER update_uploaddata_last_modified BEFORE UPDATE
    ON upload_data
        FOR EACH ROW EXECUTE PROCEDURE update_last_modified_time();

COMMIT;
